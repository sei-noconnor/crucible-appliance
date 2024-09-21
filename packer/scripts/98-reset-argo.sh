#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#

###############
#### VARS #####
###############

# Change to the current directory and inform the user
echo "Changing to script directory..."
DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR" || exit  # Handle potential errors with directory change
SCRIPTS_DIR="${PWD}"
APPS_DIR="$(readlink -m ${SCRIPTS_DIR}/../../argocd/apps)"
INSTALL_DIR="$(readlink -m ${SCRIPTS_DIR}/../../argocd/install)"

echo "Current directory: ${SCRIPTS_DIR}"  # Additional feedback
kubectl config set-context --current --namespace argocd
argocd login --core
argocd app delete apps --cascade -y

echo "Deleting APP[argocd]"
kubectl kustomize $INSTALL_DIR/argocd/kustomize/overlays/appliance --enable-helm | kubectl delete -f -
# argocd --core app delete http-echo -y --wait 
echo "Deleting 'argocd' namespace..."
kubectl delete namespace argocd 


echo "Script completed."  # Final success message


