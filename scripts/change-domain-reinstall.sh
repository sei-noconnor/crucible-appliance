#!/bin/bash 
# Get vars from appliamce.yaml
if [ -f ./appliance.yaml ]; then
  source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
fi

# Defaults
DOMAIN_DEFAULT="${DOMAIN:-onprem.imcite-phl.net}"
NEW_DOMAIN_DEFAULT="onprem.imcite-phl.net"
# Default git branch
GIT_BRANCH_DEFAULT="main"
GIT_BRANCH="$GIT_BRANCH_DEFAULT"
# Function to display usage information
usage() {
    echo
    echo "Changes all ingress objects in all namespaces to a new domain."
    echo
    echo "Usage: $0 [-n|--new-domain <domain>] [-d|--domain <domain>] [-b|--branch <branch>]"
    echo
    echo "Options:"
    echo "  -n, --new-domain        Domain to change to  (default: $NEW_DOMAIN_DEFAULT)"
    echo "  -d, --domain            Original Domain you want to rename  (default: $DOMAIN_DEFAULT)"
    echo "  -b, --branch            Git branch to use  (default: $GIT_BRANCH_DEFAULT)"
    echo "  -h, --help              Show this message"
    exit 1
}

# Parsing arguments with short and long named variables
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--new-domain) NEW_DOMAIN="$2"; shift ;;
        -d|--domain) DOMAIN="$2"; shift ;;
        -b|--branch) GIT_BRANCH="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Assign default values if not provided
DOMAIN="${DOMAIN:-$DOMAIN_DEFAULT}"
NEW_DOMAIN="${NEW_DOMAIN:-$NEW_DOMAIN_DEFAULT}"
GIT_BRANCH="${GIT_BRANCH:-$GIT_BRANCH_DEFAULT}"
echo
echo "DOMAIN: $DOMAIN"
echo "NEW DOMAIN: $NEW_DOMAIN"
echo "GIT BRANCH: $GIT_BRANCH"

echo "$SSH_PASSWORD" | sudo -E -S ./scripts/add-hosts-entry.sh -f /etc/hosts -r $NEW_DOMAIN,cd.$NEW_DOMAIN,keystore.$NEW_DOMAIN,id.$NEW_DOMAIN,code.$NEW_DOMAIN -a upsert

# backup container images
if [ ! -f ./dist/containers/images-amd64.tar.zst ]; then 
    make gitea-export-images
fi

# Update domain variable in appliance.yaml
if [ -f ./appliance.yaml ]; then
    yq -i ".vars.domain = \"$NEW_DOMAIN\"" ./appliance.yaml
fi

# uninstall K3s
make uninstall
echo "Sleeping 10 seconds"
sleep 10
make init