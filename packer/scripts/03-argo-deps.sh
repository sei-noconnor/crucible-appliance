#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#
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

if [ -d "$REPO_DEST" ]; then
  kubectl kustomize $REPO_DEST/argocd/install/cert-manager/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
  time=10
  echo "sleeping $time"
  sleep $time
  kubectl wait deployment \
  --all \
  --for=condition=Available \
  --namespace=cert-manager \
  --timeout=5m

  # Quick Fix for ClusterIssuer CRD Reapply Cert-Manager
  kubectl kustomize $REPO_DEST/argocd/install/cert-manager/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
  time=10
  echo "sleeping $time"
  sleep $time
  kubectl wait deployment \
  --all \
  --for=condition=Available \
  --namespace=cert-manager \
  --timeout=5m

  kubectl kustomize $REPO_DEST/argocd/install/nginx/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
  time=10
  echo "sleeping $time"
  sleep $time
  kubectl wait deployment \
  --all \
  --for=condition=Available \
  --namespace=ingress-nginx \
  --timeout=5m
  kubectl kustomize $REPO_DEST/argocd/install/longhorn/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
  time=10
  echo "sleeping $time"
  sleep $time
  kubectl wait deployment \
  --all \
  --for=condition=Available \
  --namespace=longhorn-system \
  --timeout=5m
  # set default storageclass to longhorn remove local-path as deafult storageclass
  kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
  kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
  kubectl kustomize $REPO_DEST/argocd/install/nfs-server/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
  kubectl kustomize $REPO_DEST/argocd/install/postgres/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
  kubectl kustomize $REPO_DEST/argocd/install/gitea/kustomize/overlays/appliance --enable-helm | kubectl apply -f -
  kubectl kustomize $REPO_DEST/argocd/install/vault/kustomize/overlays/appliance --enable-helm | kubectl apply -f - || true
else
  echo "Temporary Repo at $REPO_DEST does not exist! Install will fail"
  exit 1 
fi