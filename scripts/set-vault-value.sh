#!/bin/bash

# Define local and remote ports for Vault
localport="8200"
typename="service/appliance-vault"
remoteport="8200"
export VAULT_ADDR="http://127.0.0.1:8200"

# Define repository and YAML directory paths
REPO_DIR="/home/crucible/crucible-appliance"
YAML_DIR="argocd/install/vault/kustomize/base/files"

# Wait for the Vault pod to be running and forward the port
while ! nc -vz localhost $localport > /dev/null 2>&1 ; do
  echo "waiting for pod to be running"
  k3s kubectl wait --for=condition=running pod -l app.kubernetes.io/name=vault -n vault --timeout=5s
  echo "sleeping"
  sleep 5
  echo "Forwarding port..."
  k3s kubectl port-forward -n vault $typename $localport:$remoteport > /dev/null 2>&1 &
  pid=$!
  echo "pid: $pid"
done

# Clean up port-forward on exit
trap 'echo "Cleaning up port-forward..."; kill $pid' EXIT

# Path to the YAML file
VAULT_FILE="$REPO_DIR/$YAML_DIR/vault-keys.yaml"

# Check for vault file and initialize or unseal Vault as needed
if [[ ! -f "$VAULT_FILE" ]]; then
	echo "Initializing vault."
	INIT_DATA=$(vault operator init -format yaml)
	if [[ -n "$INIT_DATA" ]]; then
		echo "Writing init vault data to $VAULT_FILE"
		echo "$INIT_DATA" > "$VAULT_FILE"
	fi
elif [[ -f "$VAULT_FILE" ]]; then
		echo "VAULT file exists checking vault status"
		vault status -format=yaml
		initialized=$(vault status -format=yaml | yq '.initialized')
		sealed=$(vault status -format=yaml | yq '.sealed')
		if [ $initialized == false ]; then
			echo "Vault File exist, but vault is not initialized, overwriting $VAULT_FILE"
			INIT_DATA=$(vault operator init -format yaml)
			if [[ -n "$INIT_DATA" ]]; then
				echo "Writing init vault data to $VAULT_FILE"
				echo "$INIT_DATA" > "$VAULT_FILE"
			fi
		fi
		echo "Sealed Status: $sealed"
		if [ $sealed == true ]; then
			echo "Vault is sealed, attempting to unseal"
		fi
else
	echo "No Data and no file exiting, vault cannot be instantiated"
	exit 0
fi

# Extract root token and login to Vault
ROOT_TOKEN=$(grep "root_token:" "$VAULT_FILE" | awk '{print $2}')
vault login ${ROOT_TOKEN}

