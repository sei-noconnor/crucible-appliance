#!/bin/bash
#!/bin/bash

# Default values
CLUSTER_NAME_DEFAULT="githubactions"
NS_DEFAULT="github"
GH_REPO_DEFAULT="crucible-appliance"
GH_OWNER_DEFAULT="sei-noconnor"

# Parsing arguments with short and long named variables
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--cluster-name) CLUSTER_NAME="$2"; shift ;;
        -n|--namespace) NS="$2"; shift ;;
        -o|--gh-owner) GH_OWNER="$2"; shift ;;
        -r|--gh-repo) GH_REPO="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Assign default values if not provided
CLUSTER_NAME="${CLUSTER_NAME:-$CLUSTER_NAME_DEFAULT}"
NS="${NS:-$NS_DEFAULT}"
GH_REPO="${GH_REPO:-$GH_REPO_DEFAULT}"
GH_OWNER="${GH_OWNER:-$GH_OWNER_DEFAULT}"

# Check if GITHUB_PERSONAL_TOKEN is set
if [ -n "$GITHUB_PERSONAL_TOKEN" ]; then
    echo "GITHUB_PERSONAL_TOKEN is set."
    
else
    echo "GITHUB_PERSONAL_TOKEN is not set. Please set the token"
    exit 2
fi

# Debugging output
echo "Cluster Name: $CLUSTER_NAME"
echo "Namespace: $NS"
echo "GitHub Owner: $GH_OWNER"
echo "GitHub Repo: $GH_REPO"

echo "building the github runner image"
docker build --platform linux/amd64 ./.github/runners/. -t github-runner:latest

echo "creating kind cluster with name $CLUSTER_NAME"
kind create cluster -n $CLUSTER_NAME
echo "deploying github runner to $CLUSTER_NAME on $NS namespace"
echo "load github-runner to kind cluster $CLUSTER_NAME"
kind load docker-image github-runner:latest -n $CLUSTER_NAME
kubectl create ns $NS
kubectl -n $NS create secret generic github-secret \
  --from-literal GITHUB_OWNER=$GH_OWNER \
  --from-literal GITHUB_REPOSITORY=$GH_REPO \
  --from-literal GITHUB_PERSONAL_TOKEN="$GITHUB_PERSONAL_TOKEN" 
kubectl apply -f ./.github/runners/kubernetes.yaml -n $NS

# Cleanup
stop() {
    kubectl delete -f kubernetes.yaml -n $NS
}
trap 'remove; exit 130' INT
trap 'stop; exit 149' TERM