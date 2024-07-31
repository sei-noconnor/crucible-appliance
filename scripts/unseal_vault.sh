#!/bin/bash
# Change to the current directory and inform the user
echo "Changing to script directory..."
DIR=$(dirname "${BASH_SOURCE[0]}")
echo "changing directory to: $DIR"
cd "$DIR" || exit  # Handle potential errors with directory change
echo "$(readlink -e $PWD)"
SCRIPTS_DIR="$PWD"
DIST_DIR="$(readlink -e $SCRIPTS_DIR/../dist)"
echo "DIST_DIR: ${DIST_DIR}"
VAULT_UNSEAL_KEY=$(jq -r '.unseal_keys_b64[]' $DIST_DIR/cluster-keys.json) 
kubectl exec -n vault vault-0 -- vault operator unseal "$VAULT_UNSEAL_KEY"
