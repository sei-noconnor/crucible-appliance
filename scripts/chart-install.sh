#!/bin/bash
if [ -f ./appliance.yaml ]; then
  source ./packer/scripts/lib/functions.sh
  yaml_to_env "./appliance.yaml"
fi
CHART_DIR="./argocd/local-charts/crucible"
DEPENDENCYS_CHART_DIR="${SRCT_DIR}/charts"
TMP_DIR=$(mktemp -d)
OP=$1
#trap 'rm -rf "$TMP_DIR"' EXIT

cp -R ${CHART_DIR}/* ${TMP_DIR}/

cat ${CHART_DIR}/values.yaml | envsubst > ${TMP_DIR}/values.yaml
kubectl create namespace crucible || true
kubectl create namespace cert-manager|| true

helm template ${TMP_DIR} \
  --include-crds \
  --output-dir ${TMP_DIR}/generated \
  --name-template crucible \
  --values ${TMP_DIR}/values.yaml

#find crd folders and apply them first
find ${TMP_DIR}/generated -type d -name crds | while read -r dir; do
  echo "${OP}ing CRDs from $dir"
  kubectl apply -R -f "$dir"
done

kubectl $OP -R -f ${TMP_DIR}/generated