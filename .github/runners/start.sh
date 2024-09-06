#!/bin/bash -x

# Default values
CLUSTER_NAME_DEFAULT="githubactions"
NS_DEFAULT="github"
GH_REPO_OWNER_DEFAULT="sei-noconnor"
GH_REPO_DEFAULT="crucible-appliance"
GH_RUNNER_DELETE_DEFAULT=false

# Function to display usage information
usage() {
    echo "Usage: $0 [-c|--cluster-name <name>] [-n|--namespace <namespace>] [-o|--gh-owner <owner>] [-r|--gh-repo <repo>]"
    echo
    echo "Options:"
    echo "  -c, --cluster-name    Name of the cluster (default: $CLUSTER_NAME_DEFAULT), specify existing cluster"
    echo "  -n, --namespace       Kubernetes namespace (default: $NS_DEFAULT)"
    echo "  -o, --gh-owner        GitHub owner (default: $GH_REPO_OWNER_DEFAULT)"
    echo "  -r, --gh-repo         GitHub repository (default: $GH_REPO_DEFAULT)" 
    echo "  -d, --delete          Delete the gitlab runner and kind cluster"
    echo "  -h, --help            Display this help message"
    exit 1
}

# Parsing arguments with short and long named variables
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--cluster-name) CLUSTER_NAME="$2"; shift ;;
        -n|--namespace) NS="$2"; shift ;;
        -o|--gh-owner) GH_OWNER="$2"; shift ;;
        -r|--gh-repo) GH_REPO="$2"; shift ;;
        -d|--delete) GH_RUNNER_DELETE=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Assign default values if not provided
CLUSTER_NAME="${CLUSTER_NAME:-$CLUSTER_NAME_DEFAULT}"
NS="${NS:-$NS_DEFAULT}"
GH_REPO="${GH_REPO:-$GH_REPO_DEFAULT}"
GH_OWNER="${GH_OWNER:-$GH_REPO_OWNER_DEFAULT}"
GH_RUNNER_DELETE="${GH_RUNNER_DELETE:-$GH_RUNNER_DELETE_DEFAULT}"

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

# Remove Github Runner
if [[ "$GH_RUNNER_DELETE" = true ]]; then
    echo "Delete Runner flag set, Deleteing Runner"
    kubectl delete --wait -f ./.github/runners/kubernetes.yaml -n $NS
    kind delete cluster --name $CLUSTER_NAME
    exit 0
fi

echo "building the github runner image"
docker build --platform linux/amd64 ./.github/runners/. -t github-runner:latest

# Check to see if the cluster name is in our current config, use existing cluster
clusters=$(kubectl config get-contexts --no-headers | awk '{print $2}')
if [[ "$clusers[*]" =~ "$CLUSTER_NAME" ]]; then 
    while true; do
        read -p "Use existing context? " yn
        case $yn in
            [Yy]* ) echo "using current cluster"; break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    # wait for input logic
else
    # create the kind cluster
    echo "creating kind cluster with name $CLUSTER_NAME"
    kind create cluster -n $CLUSTER_NAME
    echo "load github-runner to cluster $CLUSTER_NAME"
    # Figure out how to load image in existing cluster
    kind load docker-image github-runner:latest --name $CLUSTER_NAME
    echo "deploying github runner to $CLUSTER_NAME on $NS namespace"
fi

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