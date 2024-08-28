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
# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

cd "$DIR" || exit  # Handle potential errors with directory change
SCRIPTS_DIR="${PWD}"
echo "Checking if CHARTS Directory exists at ${SCRIPTS_DIR}/../../dist/charts" 
if [ ! -d "${SCRIPTS_DIR}/../../dist/charts" ]; then
  echo "Creating Charts Directory ${SCRIPTS_DIR}/../../dist/charts"
  mkdir -p "${SCRIPTS_DIR}/../../dist/charts"
fi
# set all config dirs to absolute paths
CHARTS_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../dist/charts)"
INSTALL_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../argocd/install)"
DIST_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../dist)"
APPS_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../argocd/apps/)"

echo "CHARTS_DIR: ${CHARTS_DIR}"
echo "INTALL_DIR: ${INSTALL_DIR}"

# Install ArgoCD
kubectl kustomize $INSTALL_DIR/argocd/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
time=2
echo "Sleeping $time"
sleep $time
# Wait for ArgoCD
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
kubectl exec $POD -- bash -c "rm -rf /tmp/argo"
kubectl exec $POD -- bash -c "mkdir -p /tmp/argo"
kubectl cp "$APPS_DIR" $POD:/tmp/argo/apps
kubectl cp "$INSTALL_DIR" $POD:/tmp/argo/install
kubectl exec $POD -- bash -c "cd /tmp/argo && \
  git init . && \
  git add --all && \
  git -c user.name='Admin' -c user.email='admin@crucible.dev' commit -m 'Initial Commit'"

echo "Sleeping..."

kubectl apply -f $APPS_DIR/Application.yaml
# kubectl apply -f $APPS_DIR/cert-manager/Application.yaml
# kubectl apply -f $APPS_DIR/nginx/Application.yaml
# kubectl apply -f $APPS_DIR/http-echo/Application.yak3s-ml
# kubectl apply -f $APPS_DIR/postgres/Application.yaml
# kubectl apply -f $APPS_DIR/gitea/Application.yaml
# kubectl apply -f $APPS_DIR/keycloak/Application.yaml

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