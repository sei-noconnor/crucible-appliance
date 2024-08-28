#!/bin/bash
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <cluster_name> <cluster_ns> <github_owner> <repo_name>"
    exit 1
fi

cluster_name=${1:-githubactions}
shift
ns=${1:-github}
shift
gh_owner=${1}
shift
gh_repo=${1:-crucible-appliance-argo}
shift

echo "building the github runner image"
docker build --platform linux/amd64 ./.github/runners/. -t github-runner:latest

echo "creating kind cluster with name $cluster_name"
kind create cluster -n $cluster_name
echo "deploying github runner to $cluster_name on $ns namespace"
echo "load github-runner to kind cluster $cluster_name"
kind load docker-image github-runner:latest -n $cluster_name
kubectl create ns $ns
kubectl -n $ns create secret generic github-secret \
  --from-literal GITHUB_OWNER=$gh_owner \
  --from-literal GITHUB_REPOSITORY=$gh_repo \
  --from-literal GITHUB_PERSONAL_TOKEN="$GITHUB_PERSONAL_TOKEN" 
kubectl apply -f ./.github/runners/kubernetes.yaml -n $ns

# Cleanup
stop() {
    kubectl delete -f kubernetes.yaml -n $ns
}
trap 'remove; exit 130' INT
trap 'stop; exit 149' TERM