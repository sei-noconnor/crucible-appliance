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

echo "Deleting App[app-of-apps]"
kubectl delete --wait -f $APPS_DIR/Application.yaml

echo "Deleting APP[argocd]"
kubectl kustomize $INSTALL_DIR/argocd/kustomize/overlays/appliance --enable-helm | kubectl delete -f -
# argocd --core app delete http-echo -y --wait 


# echo "Deleting 'argocd' namespace..."
# kubectl delete namespace argocd --wait || exit  # Exit if namespace deletion fails
# Delete Brew
echo "ubuntu" sudo -S NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
echo "ubuntu" | sudo -S rm -rf /home/linuxbrew/
# Delete k3s
echo "ubuntu" | sudo -S /usr/local/bin/k3s-uninstall.sh
echo "Script completed."  # Final success message


