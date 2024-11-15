#!/bin/bash -x

localport=8200
typename=service/appliance-vault
remoteport=8200
export VAULT_ADDR='http://127.0.0.1:8200'
YAML_DIR=argocd/install/vault/kustomize/base/files
# This would show that the port is closed
# nmap -sT -p $localport localhost || true
echo "Forwarding port..."
kubectl port-forward -n vault $typename $localport:$remoteport > /dev/null 2>&1 &

pid=$!
# echo pid: $pid

# kill the port-forward regardless of how this script exits
trap '{
    # echo killing $pid
    kill $pid
}' EXIT

# wait for $localport to become available
while ! nc -vz localhost $localport > /dev/null 2>&1 ; do
    echo sleeping
    sleep 0.1
done
echo "Initializing vault."
INIT_DATA=$(vault operator init -format yaml)

# Path to the YAML file
YAML_FILE="./argocd/install/vault/kustomize/base/files/vault-keys.yaml"

if [[ -n "$INIT_DATA" ]]; then
    echo "Writing init vault data to $YAML_FILE"
    
    echo "$INIT_DATA" > "$YAML_FILE"
  elif [[ -f "$YAML_FILE" ]]; then
    echo "VAULT file exists"
  else
    echo "No Data and no file exiting..."
    exit 1
  fi

# Extract root token
ROOT_TOKEN=$(grep "root_token:" "$YAML_FILE" | awk '{print $2}')

# Extract unseal threshold
UNSEAL_THRESHOLD=$(grep "unseal_threshold:" "$YAML_FILE" | awk '{print $2}')

# Extract unseal keys (base64) into an array
readarray -t UNSEAL_KEYS < <(awk '/unseal_keys_b64:/ {flag=1; next} /unseal_keys_hex:/ {flag=0} flag' "$YAML_FILE" | sed 's/- //g')

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

echo "Creating appliance key value store"
vault secrets enable -path=crucible-appliance kv
VAULT_ARGO_AGENT=$(cat <<-EOF
  path "crucible-appliance/*" 
  {
	  capabilities = ["read"]
  }
EOF
)
echo "$VAULT_ARGO_AGENT" | vault policy write argo-vault-agent -
vault auth enable approle
vault write auth/approle/role/argo-vault-agent token_policies=argo-vault-agent
vault read -format=yaml auth/approle/role/argo-vault-agent/role-id > "$YAML_DIR"/argo-role-id.yaml
vault write --format=yaml -f auth/approle/role/argo-vault-agent/secret-id > "$YAML_DIR"/argo-secret-id.yaml

TLS_ROOT_CA=$(awk '{printf "%s\\n", $0}' "dist/ssl/server/tls/root-ca.pem")
TLS_ROOT_CA_B64=$(echo "${TLS_ROOT_CA}" | base64 )
TLS_ROOT_KEY=$(awk '{printf "%s\\n", $0}' "dist/ssl/server/tls/root-ca.key")
TLS_ROOT_KEY_B64=$(echo "${TLS_ROOT_KEY}" | base64)
SHARED_VALUES=$(cat <<-EOF
  {
    "crucible-admin-pass": "${ADMIN_PASS}",
    "crucible-admin-user": "crucible-admin@${DOMAIN}",
    "crucible-log-level": "Information",
    "domain": "${DOMAIN}",
    "fortress-tls-fullchain": "${TLS_ROOT_CA}",
    "fortress-tls-fullchain-b64": "${TLS_ROOT_CA_B64}",
    "fortress-tls-key": "${TLS_ROOT_KEY}",
    "fortress-tls-key-b64": "${TLS_ROOT_KEY_B64}",
    "http_proxy": "http://cloudproxy.sei.cmu.edu:80",
    "https_proxy": "http://cloudproxy.sei.cmu.edu:80",
    "ingress-class": "nginx",
    "no_proxy": "localhost,.cmu.edu,.cert.org,.cwd.local,osticket-mysql,10.64.149.0/24,10.42.0.0/16,10.43.0.0/16",
    "oauth-admin-guid": "d29518c4-f61c-4284-81c4-f2fbd79e6e9a",
    "oauth-authority-url": "realms/crucible",
    "oauth-authorization-url": "realms/crucible/protocol/openid-connect/auth",
    "oauth-crucible-admin-guid": "d29518c4-f61c-4284-81c4-f2fbd79e6e9a",
    "oauth-env": "fortress",
    "oauth-gid": "00eb8904-5b88-4c68-ad67-cec0d2e07aa6",
    "oauth-provider": "keycloak",
    "oauth-token-url": "realms/crucible/protocol/openid-connect/token\n ",
    "oauth-userapi-url": "realms/crucible/protocol/openid-connect/userinfo"
  }
EOF
)

echo ${SHARED_VALUES} > shared.json
vault kv put -mount=crucible-appliance shared @shared.json