#!/bin/bash -x
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
rsync -avP $REPO_DIR/ $REPO_DEST/


# Add certificate to topomojo, This is the only way it works. TODO: Update topomojo helm chart
cat $DIST_DIR/ssl/server/tls/root-ca.pem | sed 's/^/        /' | sed -i -re 's/(cacert.crt:).*/\1 |-/' -e '/cacert.crt:/ r /dev/stdin' $APPS_DIR/topomojo/kustomize/base/files/topomojo.values.yaml

# Add root-ca configmap to default namespace
kubectl -n default create configmap root-ca --from-file=root-ca.crt=$DIST_DIR/ssl/server/tls/root-ca.pem

# Update argocd admin password in argocd values
export ARGO_ADMIN_PASS=$(htpasswd -nbBC 10 "" "$ADMIN_PASS" | tr -d ':\n' | sed 's/$2y/$2a/')

# Need unwrapscalar to preserve formating of "|-" "|" "->"
#yq -i --unwrapScalar=true '.configs.secret.argocdServerAdminPassword = env(ARGO_ADMIN_PASS)' ${INSTALL_DIR}/argocd/kustomize/base/files/argocd.values.yaml

# Install ArgoCD
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

kubectl apply -f $REPO_DEST/argocd/patches/Application.yaml
kubectl apply -f $REPO_DEST/argocd/apps/prod-argo/root-app.yaml

time=60
echo "Sleeping $time seconds to wait for apps to sync"
sleep $time

Wait for Deployments (most apps)
echo "Waiting for ALL deployments 'Status: Avaialble' This may cause a timeout."
kubectl wait deployment \
--all \
--for=condition=Available \
--all-namespaces=true \
--timeout=5m

#rm -rf $REPO_DEST
