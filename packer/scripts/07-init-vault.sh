#!/bin/bash -x

localport=8200
typename=service/appliance-vault
remoteport=8200
export VAULT_ADDR='http://127.0.0.1:8200'
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