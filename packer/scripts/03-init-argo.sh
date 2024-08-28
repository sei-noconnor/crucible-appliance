#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#
# Variables (Initialize to defaults or empty)
service_name="argocd-repo-server"
secret_name=""
local_port="8080"
remote_port="443"
namespace="argocd"

# Change to the current directory and inform the user
echo "Changing to script directory..."
DIR=$(dirname "${BASH_SOURCE[0]}")
echo "changing directory to: $DIR"

cd "$DIR" || exit  # Handle potential errors with directory change
SCRIPTS_DIR="${PWD}"
echo "Checking if CHARTS Directory exists at ${SCRIPTS_DIR}/../../dist/charts" 
if [ ! -d "${SCRIPTS_DIR}/../../dist/charts" ]; then
  echo "Creating Charts Directory ${SCRIPTS_DIR}/../../dist/charts"
  mkdir -p "${SCRIPTS_DIR}/../../dist/charts"
fi
CHARTS_DIR="$(readlink -e ${SCRIPTS_DIR}/../../dist/charts)"
VALUES_DIR="$(readlink -e ${SCRIPTS_DIR}/../../argocd/values)"
DIST_DIR="$(readlink -e ${SCRIPTS_DIR}/../../dist)"

echo "CHARTS_DIR: ${CHARTS_DIR}"
echo "VALUES_DIR: ${VALUES_DIR}"

# Install vault
helm repo add hashicorp https://helm.releases.hashicorp.com 
echo "Checking if CHARTS Directory exists at ${CHARTS_DIR}" 
if [ ! -d "${CHARTS_DIR}" ]; then
  echo "Creating Charts Directory ${CHARTS_DIR}"
  mkdir -p "${CHARTS_DIR}"
fi
kubectl create namespace vault
if [ ! -f ${CHARTS_DIR}/vault-0.28.0.tgz ]; then
  echo "Chart not downloaded, downloading now..."
  helm pull hashicorp/vault -d "${CHARTS_DIR}" --version 0.28.0 
fi
echo "Installing from downloaded chart"
helm upgrade --install vault "${CHARTS_DIR}/vault-0.28.0.tgz" -f "${VALUES_DIR}/vault.values.yaml" -n vault
#helm install vault hashicorp/vault --namespace vault --version 0.28.0

# Configure vault
kubectl wait -n vault --for=condition=Ready pod/vault-0
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=1 \
  -key-threshold=1 \
  -format=json > "${DIST_DIR}/cluster-keys.json"

VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" ${DIST_DIR}/cluster-keys.json)
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY


kubectl create namespace argocd
kubectl apply -f ../../argocd/manifests/core-install.yaml -n argocd --wait

echo "Waiting for service '$service_name' in namespace '$namespace' to become ready..."

# Wait for the service to have an endpoint (indicating readiness)
while ! kubectl get endpoints "$service_name" -n "$namespace" &> /dev/null; do 
    sleep 2 
    echo "Service not ready yet. Retrying..."
done

echo "Service is ready. Configuring Argo CD"

# # Port-forward the service to the local port
# kubectl port-forward svc/"$service_name" -n "$namespace" "$local_port":"$remote_port" &

# # Get the process ID of the port-forwarding command
# port_forward_pid=$!

# # Trap signals to gracefully terminate the port-forwarding process
# trap "echo 'Stopping port-forwarding...'; kill $port_forward_pid" SIGINT SIGTERM

# # Wait for the port-forwarding process to finish (usually runs indefinitely)
# wait $port_forward_pid

# argocd admin $$argo_pass -n argocd

# # Get all namespaces
# namespaces=$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

# # Loop through namespaces and delete the secret
# for ns in $namespaces; do
#     if kubectl get secret "$secret_name" -n "$ns" &> /dev/null; then  # Check if secret exists
#         echo "Deleting secret '$secret_name' from namespace '$ns'"
#         kubectl delete secret "$secret_name" -n "$ns"
#     else
#         echo "Secret '$secret_name' not found in namespace '$ns'"
#     fi
# done
# kubectl delete secret argocd-initial-admin-secret -n argocd

kubectl config set-context --current --namespace=argocd
argocd login --core

