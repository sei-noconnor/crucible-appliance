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

echo "Current directory: ${SCRIPTS_DIR}"  # Additional feedback

echo "Deleting APP[http-echo]"
argocd --core app delete http-echo -y --wait 

echo "Deleting APP[postgres]"
argocd --core app delete postgres -y --wait 

echo "Deleting APP[nginx]"
argocd --core app delete nginx -y --wait 

echo "Deleting existing Argo CD installation..."
kubectl delete -f ../../argocd/manifests/core-install.yaml --wait -n argocd 

echo "Deleting 'argocd' namespace..."
kubectl delete namespace argocd --wait || exit  # Exit if namespace deletion fails

echo "Script completed."  # Final success message


