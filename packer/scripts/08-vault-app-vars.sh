#!/bin/bash 
# Get vars from appliamce.yaml
if [ -f ./appliance.yaml ]; then
 #source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
 export $(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
fi
localport=8200
typename=service/appliance-vault
remoteport=8200
export VAULT_ADDR='http://127.0.0.1:8200'
REPO_DIR=/home/crucible/crucible-appliance
VAULT_DIR=argocd/install/vault/kustomize/base/files
VAULT_FILE="${REPO_DIR}/${VAULT_DIR}/vault-keys.yaml"
# Extract root token
ROOT_TOKEN=$(grep "root_token:" "$VAULT_FILE" | awk '{print $2}')
# Configuration
VAULT_TOKEN="${ROOT_TOKEN}"
VAULT_KV_PATH="fortress-prod"
VARS_TEMPLATE="${REPO_DIR}/${VAULT_DIR}/app-vars.example.yaml"
VARS_FILE="${REPO_DIR}/${VAULT_DIR}/app-vars.yaml"

# This would show that the port is closed
# nmap -sT -p $localport localhost || true

# wait for $localport to become available
while ! nc -vz localhost $localport > /dev/null 2>&1 ; do
  echo "waiting for pod to be running"
  sudo k3s kubectl wait --for=condition=running pod -l app.kubernetes.io/name=vault -n vault --timeout=5s
  echo "sleeping"
  sleep 5
  echo "Forwarding port..."
  sudo k3s kubectl port-forward -n vault $typename $localport:$remoteport > /dev/null 2>&1 &
  pid=$!
  echo "pid: $pid"
done

# kill the port-forward regardless of how this script exits
trap '{
    echo "killing $pid"
    kill $pid
}' EXIT


export TLS_ROOT_CA=$(awk '{printf "%s\\n", $0}' "${REPO_DIR}/dist/ssl/server/tls/root-chain.pem")
export TLS_ROOT_CA_B64=$(echo "${TLS_ROOT_CA}" | base64 )
export TLS_ROOT_KEY=$(awk '{printf "%s\\n", $0}' "${REPO_DIR}/dist/ssl/server/tls/intermediate-ca.key")
export TLS_ROOT_KEY_B64=$(echo "${TLS_ROOT_KEY}" | base64)

echo "logging into vault"
vault login ${ROOT_TOKEN}

echo "Creating appliance key value store"
vault secrets enable -path="${VAULT_KV_PATH}" -version=2 kv
if [ ! -f ${VARS_FILE} ]; then 
    cat ${VARS_TEMPLATE} | envsubst > ${VARS_FILE}
fi
for key in $(yq 'keys | .[]' "${VARS_FILE}"); do
    echo "Parsing top-level key $key"
    payload=$(yq eval "... |= select(. == null) |= \"\" | .\"$key\"" -o=json "$VARS_FILE")

    curl --silent --show-error --fail \
        --header "X-Vault-Token: $VAULT_TOKEN" \
        --request POST \
        --data "{\"data\": $payload }" \
        "$VAULT_ADDR/v1/$VAULT_KV_PATH/data/$key"
    
    if [ $? -eq 0 ]; then
        echo "Uploaded $key to $VAULT_KV_PATH"
    else
        echo "Failed to upload $key to $VAULT_KV_PATH" >&2
    fi
done