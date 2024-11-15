#!/bin/bash

# Configuration
VAULT_ADDR="http://127.0.0.1:8200" # Replace with your Vault server address
VAULT_TOKEN="your-vault-token"    # Replace with your Vault token
VAULT_KV_PATH="kv/data"           # Replace with your KV mount path
YAML_FILE="config.yaml"           # Replace with your YAML file path

# Function to upload to Vault
upload_to_vault() {
    local service=$1
    local key=$2
    local value=$3

    # Prepare the payload
    payload=$(jq -n --arg k "$key" --arg v "$value" '{"data": {($k): $v}}')

    # Vault API call
    curl --silent --show-error --fail \
        --header "X-Vault-Token: $VAULT_TOKEN" \
        --request POST \
        --data "$payload" \
        "$VAULT_ADDR/v1/$VAULT_KV_PATH/$service"
    
    if [ $? -eq 0 ]; then
        echo "Uploaded $key to $VAULT_KV_PATH/$service"
    else
        echo "Failed to upload $key to $VAULT_KV_PATH/$service" >&2
    fi
}

# Process the YAML file
while IFS= read -r line; do
    # Extract service, key, and value
    if [[ $line =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*(.+)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        # Remove quotes if present
        value=$(echo "$value" | sed -e "s/^['\"]//" -e "s/['\"]$//")
        # Upload the key-value pair
        upload_to_vault "$current_service" "$key" "$value"
    elif [[ $line =~ ^([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
        current_service="${BASH_REMATCH[1]}"
    fi
done < <(yq eval '.' "$YAML_FILE")
