#!/bin/bash

localport=8200
typename=service/appliance-vault
remoteport=8200
export VAULT_ADDR='http://127.0.0.1:8200'
REPO_DIR=/home/crucible/crucible-appliance
YAML_DIR=argocd/install/vault/kustomize/base/files
# This would show that the port is closed
# nmap -sT -p $localport localhost || true
# wait for $localport to become available


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

# kill the port-forward regardless of how this script exits
trap '{
    echo "killing $pid"
    kill $pid
}' EXIT

VAULT_KEYS_FILE="./argocd/install/vault/kustomize/base/files/vault-keys.yaml"
VAULT_ARGO_ROLE_ID_FILE="./argocd/install/argocd/kustomize/overlays/appliance/files/argo-role-id"
VAULT_ARGO_SECRET_ID_FILE="./argocd/install/argocd/kustomize/overlays/appliance/files/argo-secret-id"
# Extract root token
ROOT_TOKEN=$(grep "root_token:" "$VAULT_KEYS_FILE" | awk '{print $2}')

vault login ${ROOT_TOKEN}

if [ ! -f $VAULT_ARGO_ROLE_ID_FILE ]; then
VAULT_ARGO_AGENT=$(cat <<-EOF
path "fortress-prod/*" 
{
    capabilities = ["read"]
}
EOF
)
echo "$VAULT_ARGO_AGENT" | vault policy write argo-vault-agent - || true
vault auth enable approle || true
vault write auth/approle/role/argo-vault-agent token_policies=argo-vault-agent
vault read -format=yaml auth/approle/role/argo-vault-agent/role-id | grep "role_id:" | awk '{print $2}' > $VAULT_ARGO_ROLE_ID_FILE
fi
if [ ! -f $VAULT_ARGO_SECRET_ID_FILE ]; then 
    vault write --format=yaml -f auth/approle/role/argo-vault-agent/secret-id | grep "secret_id:" | awk '{print $2}' > $VAULT_ARGO_SECRET_ID_FILE
fi 

