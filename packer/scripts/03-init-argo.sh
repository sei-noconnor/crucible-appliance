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
REPO_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../)"
REPO_DEST="/tmp/crucible-appliance"

echo "CHARTS_DIR: ${CHARTS_DIR}"
echo "INSTALL_DIR: ${INSTALL_DIR}"
echo "REPO_DIR: ${REPO_DIR}"

# Add certificate to topomojo, This is the only way it works. TODO: Update topomojo helm chart
cat $DIST_DIR/ssl/server/tls/root-ca.pem | sed 's/^/        /' | sed -i -re 's/(cacert.crt:).*/\1 |-/' -e '/cacert.crt:/ r /dev/stdin' $APPS_DIR/topomojo/kustomize/base/files/topomojo.values.yaml

# Install ArgoCD
rm -rf $REPO_DEST
mkdir -p $REPO_DEST
cp -rp $REPO_DIR/. $REPO_DEST/
GIT_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)
echo "REPO Destination: $REPO_DEST"
cd "$REPO_DEST"
find . -name "Application.yaml" -exec sed -i "s/main/${GIT_BRANCH}/g" {} \;
# allow root-ca.pem to be commited.
echo "!**/*/root-ca.pem" >> .gitignore
# allow root-ca.key to be commited. This is bad, use a vault!
echo "!**/*/root-ca.key" >> .gitignore
git checkout $GIT_BRANCH
git  add -u 
git add "**/*.pem"
git add "**/*.key"
git -c user.name="admin" -c user.email="admin@crucible.local" commit -m "Appliance Init, it's your repo now!" 

kubectl kustomize $REPO_DEST/argocd/install/cert-manager/kustomize/overlays/appliance --enable-helm | kubectl apply --wait=true -f -
sleep 10
kubectl wait deployment \
--all \
--for=condition=Available \
--namespace=cert-manager \
--timeout=5m

kubectl kustomize $REPO_DEST/argocd/install/nginx/kustomize/overlays/appliance --enable-helm | kubectl apply --wait=true -f -
sleep 10
kubectl wait deployment \
--all \
--for=condition=Available \
--namespace=ingress-nginx \
--timeout=5m
kubectl kustomize $REPO_DEST/argocd/install/longhorn/kustomize/overlays/appliance --enable-helm | kubectl apply --wait=true -f -
echo "sleeping 120"
sleep 120
kubectl wait deployment \
--all \
--for=condition=Available \
--namespace=longhorn-system \
--timeout=5m
# set default storageclass to longhorn remove local-path as deafult storageclass
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl kustomize $REPO_DEST/argocd/install/postgres/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
kubectl kustomize $REPO_DEST/argocd/install/gitea/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
kubectl kustomize $REPO_DEST/argocd/install/vault/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
kubectl kustomize $REPO_DEST/argocd/install/argocd/kustomize/overlays/appliance --enable-helm | kubectl apply -f -

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

echo "Uploading Initial Repo"

POD="$(kubectl get pods -n argocd --no-headers -l app.kubernetes.io/name=argocd-repo-server | head -n1 | awk '{print $1}')"
kubectl exec $POD -- bash -c "rm -rf /crucible-repo/crucible-appliance && mkdir -p /crucible-repo/crucible-appliance"
kubectl cp "$REPO_DEST/." "$POD:/crucible-repo/"
kubectl exec $POD -- bash -c "cd /crucible-repo/crucible-appliance && \
  git remote remove origin"

kubectl apply -f $REPO_DEST/argocd/apps/Application.yaml  
# kubectl apply -f $APPS_DIR/cert-manager/Application.yaml
# kubectl apply -f $APPS_DIR/nginx/Application.yaml
# kubectl apply -f $APPS_DIR/http-echo/Application.yaml
# kubectl apply -f $APPS_DIR/postgres/Application.yaml
# kubectl apply -f $APPS_DIR/gitea/Application.yaml
# kubectl apply -f $APPS_DIR/keycloak/Application.yaml

time=60
echo "Sleeping $time seconds to wait for apps to sync"
sleep $time

# Wait for Deployments (most apps)
echo "Waiting for ALL deployments 'Status: Avaialble' This may cause a timeout."
kubectl wait deployment \
--all \
--for=condition=Available \
--all-namespaces=true \
--timeout=5m

rm -rf $REPO_DEST
