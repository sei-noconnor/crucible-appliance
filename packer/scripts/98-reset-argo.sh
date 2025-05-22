#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#
if [ -f ./appliance.yaml ]; then
  source ./packer/scripts/lib/functions.sh
  yaml_to_env "./appliance.yaml"
fi
###############
#### VARS #####
###############

# Change to the current directory and inform the user
REPO_DEST="${1:-.}"
APPS_DIR="$(readlink -m $REPO_DEST/argocd/apps)"
INSTALL_DIR="$(readlink -m $REPO_DEST/argocd/install)"

kubectl config set-context --current --namespace argocd
argocd --core app delete root-app patches --cascade -y
log_pretty "Sleeping 60 seconds"
sleep 60 
echo "Deleting APP[argocd]"
kubectl kustomize $REPO_DEST/argocd/install/argocd/kustomize/overlays/appliance --enable-helm | kubectl delete -f -
log_pretty "Deleting APP[argocd]" "lightblue"
kubectl kustomize $REPO_DEST/argocd/install/argocd/kustomize/overlays/appliance --enable-helm | kubectl delete -f - --wait
log_pretty "Deleting ArgoCD Dependencies" "lightblue"

kubectl kustomize $REPO_DEST/argocd/install/gitea/kustomize/overlays/appliance --enable-helm | kubectl delete -f -
kubectl kustomize $REPO_DEST/argocd/install/vault/kustomize/overlays/appliance --enable-helm | kubectl delete -f - 
kubectl kustomize $REPO_DEST/argocd/install/cert-manager/kustomize/overlays/appliance --enable-helm | kubectl delete -f -
kubectl kustomize $REPO_DEST/argocd/install/postgres/kustomize/overlays/appliance --enable-helm | kubectl delete -f -
kubectl kustomize $REPO_DEST/argocd/install/nfs-server/kustomize/overlays/appliance --enable-helm | kubectl delete -f -
log_pretty "Patching longhorn so it can be uninstalled" "lightblue"
kubectl -n longhorn-system delete job longhorn-uninstall

kubectl -n longhorn-system patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag
kubectl create -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/uninstall/uninstall.yaml
# kubectl kustomize $REPO_DEST/argocd/install/longhorn/kustomize/overlays/appliance --enable-helm | kubectl delete -f -
log_pretty "sleeping 60 seconds to allow longhorn to uninstall" "lightblue"
sleep 60
kubectl -n longhorn-system delete deployments --all
kubectl -n longhorn-system delete jobs --all
kubectl kustomize $REPO_DEST/argocd/install/nginx/kustomize/overlays/appliance --enable-helm | kubectl delete -f -
#Reset longhorn 
kubectl -n longhorn-system patch -p '{"value": "false"}' --type=merge lhs deleting-confirmation-flag
kubectl delete namespace longhorn-system
echo "Script completed."  # Final success message