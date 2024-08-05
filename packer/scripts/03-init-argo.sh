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
CHARTS_DIR="$(readlink -m ${SCRIPTS_DIR}/../../dist/charts)"
VALUES_DIR="$(readlink -m ${SCRIPTS_DIR}/../../argocd/values)"
DIST_DIR="$(readlink -m ${SCRIPTS_DIR}/../../dist)"
APPS_DIR="$(readlink -m ${SCRIPTS_DIR}/../../argocd/apps/)"
echo "CHARTS_DIR: ${CHARTS_DIR}"
echo "VALUES_DIR: ${VALUES_DIR}"


kubectl create namespace argocd
kubectl apply -f ../../argocd/manifests/core-install.yaml -n argocd

kubectl wait deployment \
--all \
--for=condition=Available \
--namespace=argocd \
--timeout=5m

kubectl config set-context --current --namespace=argocd
argocd login --core
echo "sleeping ..2"
sleep 2
POD="$(kubectl get pods -n argocd --no-headers -l app.kubernetes.io/name=argocd-repo-server | head -n1 | awk '{print $1}')"
echo "Deleting nginx"
argocd app delete nginx -y || true

kubectl exec $POD -- bash -c "rm -rf /tmp/apps"
kubectl cp "$APPS_DIR" $POD:/tmp/apps
kubectl exec $POD -- bash -c "cd /tmp/apps && \
  git init . && \
  git add --all && \
  git -c user.name='Admin' -c user.email='admin@crucible.dev' commit -m 'Initial Commit'"

echo "Sleeping..."
kubectl apply -f $APPS_DIR/nginx/kustomize/overlays/appliance/Application.yaml
kubectl apply -f $APPS_DIR/http-echo/kustomize/overlays/appliance/Application.yaml
kubectl apply -f $APPS_DIR/postgres/kustomize/overlays/appliance/Application.yaml

time=10
echo "Sleeping $time seconds to wait for apps to sync"
sleep $time

echo "waiting for all apps to become available"
kubectl wait deployment \
--all \
--for=condition=Available \
--namespace=argocd \
--timeout=5m
kubectl wait pods \
appliance-postgresql-0 \
--for=condition=Ready \
--namespace=postgres \
--timeout=5m
kubectl wait deployment \
--all \
--for=condition=Available \
--namespace=default \
--timeout=5m
time=10
echo "Sleeping $time seconds to ensure all apps are updated"
sleep $time




# argocd app create nginx \
#    --repo "file:///tmp/apps" \
#    --path nginx/kustomize/overlays/appliance \ 
#    --dest-namespace argocd \
#    --dest-server https://kubernetes.default.svc

# argocd app create http-echo \
#    --repo "file:///tmp/apps" \
#    --path http-echo/kustomize/overlays/appliance \
#    --dest-namespace argocd \
#    --dest-server https://kubernetes.default.svc