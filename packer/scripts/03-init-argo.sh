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

kubectl create namespace argocd
kubectl apply -f ../../argocd/manifests/core-install.yaml -n argocd

kubectl wait deployment argocd-repo-server \
--for=condition=Available \
--namespace=argocd

kubectl config set-context --current --namespace=argocd
argocd login --core