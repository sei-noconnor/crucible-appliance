#!/bin/bash

localport="8200"
typename="service/appliance-vault"
remoteport="8200"
export VAULT_ADDR="http://127.0.0.1:8200"
REPO_DIR="/home/crucible/crucible-appliance"
YAML_DIR="argocd/install/vault/kustomize/base/files"
# This would show that the port is closed
# nmap -sT -p $localport localhost || true
# wait for $localport to become available

while ! nc -vz localhost "$localport" > /dev/null 2>&1 ; do
  echo "waiting for pod to be running"
  sudo k3s kubectl wait --for=condition=running pod -l app.kubernetes.io/name=vault -n vault --timeout=5s
  echo "sleeping"
  sleep 5
  echo "Forwarding port $remoteport to $localport"
  sudo k3s kubectl port-forward -n vault $typename $localport:$remoteport > /dev/null 2>&1 &
  pid="$!"
  echo "pid: $pid"
done

# kill the port-forward regardless of how this script exits
trap '{
    echo "killing $pid"
    kill $pid
}' EXIT

# Path to the YAML file
VAULT_FILE="$REPO_DIR/$YAML_DIR/vault-keys.yaml"

# Check for vault file, 
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

# Extract root token
ROOT_TOKEN=$(grep "root_token:" "$VAULT_FILE" | awk '{print $2}')

# Extract unseal threshold
UNSEAL_THRESHOLD=$(grep "unseal_threshold:" "$VAULT_FILE" | awk '{print $2}')

# Extract unseal keys (base64) into an array
readarray -t UNSEAL_KEYS < <(awk '/unseal_keys_b64:/ {flag=1; next} /unseal_keys_hex:/ {flag=0} flag' "$VAULT_FILE" | sed 's/- //g')

# Display the root token
echo "Root Token: $ROOT_TOKEN"

# Display unseal threshold
echo "Unseal Threshold: $UNSEAL_THRESHOLD"

# Assign unseal keys to individual variables
for i in "${!UNSEAL_KEYS[@]}"; do
  eval "UNSEAL_KEY_$((i + 1))=${UNSEAL_KEYS[i]}"
  echo "Unseal Key $((i + 1)): ${UNSEAL_KEYS[i]}"
done

# Example: Access individual unseal keys as variables
echo
echo "Accessing individual unseal keys:"
echo "Unseal Key 1: $UNSEAL_KEY_1"
echo "Unseal Key 2: $UNSEAL_KEY_2"
echo "Unseal Key 3: $UNSEAL_KEY_3"

# Logic to automatically use the threshold number of keys for unsealing
echo
echo "Using the first $UNSEAL_THRESHOLD keys for unsealing..."
for ((i = 1; i <= UNSEAL_THRESHOLD; i++)); do
  KEY_VAR="UNSEAL_KEY_$i"
  echo "Using $KEY_VAR: ${!KEY_VAR}"
  vault operator unseal ${!KEY_VAR}
done

echo "Logining in to vault with root_key"
vault login ${ROOT_TOKEN}
sudo k3s kubectl -n vault delete jobs --all