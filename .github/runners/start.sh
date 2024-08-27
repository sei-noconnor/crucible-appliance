#!/bin/bash

cluster_name=${1:-githubactions}
ns=${2:-github}
GITHUB_PERSONAL_TOKEN=${GITHUB_PERSON_TOKEN:-""}
echo "building the github runner image"
docker build --platform linux/amd64 . -t github-runner:latest

echo "creating kind cluster with name $cluster_name"
kind create cluster -n $cluster_name
echo "deploying github runner to $cluster_name on $ns namespace"
echo "load github-runner to kind cluster $cluster_name"
kind load docker-image github-runner:latest -n $cluster_name
kubectl create ns $ns
kubectl -n github create secret generic github-secret \
  --from-literal GITHUB_OWNER=NicCOConnor \
  --from-literal GITHUB_REPOSITORY=crucible-appliance-argo \
  --from-literal GITHUB_PERSONAL_TOKEN="$GITHUB_PERSONAL_TOKEN"
kubectl apply -f ./kubernetes.yaml -n github

# Cleanup
stop() {
    kubectl delete -f kubernetes.yaml -n $ns
}
trap 'remove; exit 130' INT
trap 'stop; exit 149' TERM