#!/bin/bash 
# Get vars from appliamce.yaml
if [ -f ./appliance.yaml ]; then
  source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
fi

# Defaults
DOMAIN_DEFAULT="${DOMAIN:-crucible.io}"
NEW_DOMAIN_DEFAULT="crucible.io"

# Function to display usage information
usage() {
    echo
    echo "Changes all ingress objects in all namespaces to a new domain."
    echo
    echo "Usage: $0 [-n|--new-domain <domain>] [-d|--domain <domain>]"
    echo
    echo "Options:"
    echo "  -n, --new-domain        Domain to change to  (default: $NEW_DOMAIN_DEFAULT)"
    echo "  -d, --domain            Original Domain you want to rename  (default: $DOMAIN_DEFAULT)"
    echo "  -h, --help              Show this message"
    exit 1
}

# Parsing arguments with short and long named variables
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--new-domain) NEW_DOMAIN="$2"; shift ;;
        -d|--domain) DOMAIN="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Assign default values if not provided
DOMAIN="${DOMAIN:-$DOMAIN_DEFAULT}"
NEW_DOMAIN="${NEW_DOMAIN:-$NEW_DOMAIN_DEFAULT}"
echo
echo "DOMAIN: $DOMAIN"
echo "NEW DOMAIN: $NEW_DOMAIN"

# # Get the number of Ingresses
# INGRESS_COUNT=$(kubectl get ing --all-namespaces -o yaml | yq eval '.items | length' -)

# # Loop through each Ingress change domain as long as the old domain string exists.
# for i in $(seq 0 $((INGRESS_COUNT - 1))); do
#     NS=$(kubectl get ing --all-namespaces -o yaml | yq eval ".items[$i].metadata.namespace" -)
#     NAME=$(kubectl get ing --all-namespaces -o yaml | yq eval ".items[$i].metadata.name" -)

#     # Get the number of rules (in case of multiple host entries)
#     HOST_COUNT=$(kubectl get ing -n "$NS" "$NAME" -o yaml | yq eval '.spec.rules | length' -)

#     for j in $(seq 0 $((HOST_COUNT - 1))); do
#         HOST=$(kubectl get ing -n "$NS" "$NAME" -o yaml | yq eval '.spec.rules[$j].host' )
#         if [[ "$HOST" =~ "$DOMAIN" ]]; then
#           echo "CHANGING HOST to $NEW_DOMAIN"
#           HOST=$(echo "$HOST" | sed "s|$DOMAIN|$NEW_DOMAIN|g")
#         fi
#         HOST_PATH="/spec/rules/$j/host"
#         kubectl patch ing "$NAME" -n "$NS" --type=json -p="$(cat <<EOF
# - op: replace
#   path: $HOST_PATH
#   value: $HOST
# EOF
# )"
#     done
#     # Get the number of hosts (in case of multiple tls entries)
#     TLS_COUNT=$(kubectl get ing -n "$NS" "$NAME" -o yaml | yq eval ".spec.tls | length" -)
#     for k in $(seq 0 $((TLS_COUNT - 1))); do
#       HOST_COUNT=$(kubectl get ing -n "$NS" "$NAME" -o yaml | yq eval ".spec.tls[$k].hosts | length" -)
#       for l in $(seq 0 $((HOST_COUNT - 1))); do
#         HOST=$(kubectl get ing -n "$NS" "$NAME" -o yaml | yq eval ".spec.tls[$k].hosts[$l]" -)
#         if [[ "$HOST" =~ "$DOMAIN" ]]; then
#           echo "CHANGING TLS HOST to $NEW_DOMAIN"
#           HOST=$(echo "$HOST" | sed "s|$DOMAIN|$NEW_DOMAIN|g")
#         fi
#         HOST_PATH="/spec/tls/$k/hosts/-"
#         kubectl patch ing "$NAME" -n "$NS" --type=json -p="$(cat <<EOF
# - op: add
#   path: $HOST_PATH
#   value: $HOST
# EOF
# )"
#       done
#     done
# done

# # update gitea ingress
# YAML=$(kubectl get ingress "appliance-gitea" -n gitea -o yaml) 
# SPEC_PATHS=$(echo "$YAML" | yq '.spec.rules[0].http.paths')
# echo "path is: $SPEC_PATHS"
# PATCH="$(cat <<-EOF
# - op: add
#   path: /spec/rules/-
#   value: 
#     host: $NEW_DOMAIN
#     http:
#       paths: 
# $(echo "$SPEC_PATHS" | sed 's/^/        /g')
# EOF
# )"

# echo "$PATCH" | yq -P

# kubectl patch ing "appliance-gitea" -n "gitea" --type=json -p="$PATCH"

# PATCH="$(cat <<-EOF
# - op: add
#   path: /spec/tls/0/0
#   value: 
#     hosts:
#       - $NEW_DOMAIN
# EOF
# )"
# echo "$PATCH" | yq -P

# kubectl patch ing "appliance-gitea" -n "gitea" --type=json -p="$PATCH"

OLD_INGRESS="appliance-gitea"
NEW_INGRESS="appliance-gitea-$NEW_DOMAIN"
NAMESPACE="gitea"
SECRET_NAME="gitea-tls-$NEW_DOMAIN"

# Get the existing Ingress YAML
kubectl get ingress $OLD_INGRESS -n $NAMESPACE -o yaml > ingress.yaml

# Use yq to modify the hosts and tls
yq eval ".metadata.name = \"$NEW_INGRESS\" |
        .spec.rules[].host = \"$NEW_DOMAIN\" |
        .spec.tls[].hosts = [\"$NEW_DOMAIN\"] |
        .spec.tls[].secretName = \"$SECRET_NAME\"" ingress.yaml > new-ingress.yaml

# Apply the modified Ingress
kubectl apply -f new-ingress.yaml


# add coredns-custom hosts entries
./scripts/add-coredns-hosts-entry.sh -n kube-system -c coredns-custom -r $NEW_DOMAIN,cd.$NEW_DOMAIN,keystore.$NEW_DOMAIN,id.$NEW_DOMAIN,code.$NEW_DOMAIN -a upsert
./scripts/add-coredns-hosts-entry.sh -n kube-system -c coredns-custom -r $DOMAIN,cd.$DOMAIN,keystore.$DOMAIN,id.$DOMAIN,code.$DOMAIN -a upsert
./scripts/add-hosts-entry.sh -f /etc/hosts -r $NEW_DOMAIN,cd.$NEW_DOMAIN,keystore.$NEW_DOMAIN,id.$NEW_DOMAIN,code.$NEW_DOMAIN -a upsert

# # add tls-san to k3s-service
# echo "Updating K3s tls san "
# echo "$SSH_PASSWORD" | \
# sudo -S sed -i "s|$DOMAIN|$NEW_DOMAIN|g" /etc/systemd/system/k3s.service &&
# sudo -S systemctl daemon-reload && \
# sudo -S systemctl restart k3s.service

# # change domian in KUBECONFIG
# echo "Updating KUBECONFIG"
# sed -i "s|$DOMAIN|$NEW_DOMAIN|g" ${KUBECONFIG:-~/.kube/config}
# kubectl get nodes

# update git repo 

REPO_DEST="/tmp/crucible-appliance"
GITEA_ORG="fortress-manifests"
GIT_BRANCH=$(git -C "$REPO_DEST" rev-parse --abbrev-ref HEAD)

find $REPO_DEST -path "$REPO_DEST/.git" -prune -o -type f -exec sed -i "s/https:\/\/${DOMAIN}\/gitea\/fortress-manifests/https:\/\/${NEW_DOMAIN}\/gitea\/fortress-manifests/g" {} +

# update URLS
find $REPO_DEST -path $REPO_DEST/.git -prune -o -exec sed -i "s/https:\/\/${DOMAIN}\/gitea\/fortress-manifests/https:\/\/${NEW_DOMAIN}\/gitea\/fortress-manifests/g" {} \;
git -C $REPO_DEST add --all
git -C $REPO_DEST commit -m "updating URLS from $DOMAIN to $NEW_DOMAIN"
# update domains
find $REPO_DEST -path $REPO_DEST/.git -prune -o -exec sed -i "s/${DOMAIN}/${NEW_DOMAIN}/g" {} \;
git -C $REPO_DEST add --all
git -C $REPO_DEST commit -m "updating all instances of $DOMAIN to $NEW_DOMAIN"

REMOTE_URL="https://administrator:crucible@${NEW_DOMAIN}/gitea/${GITEA_ORG}/crucible-appliance.git"
git -C $REPO_DEST remote add appliance "${REMOTE_URL}" 2>/dev/null || git -C $REPO_DEST remote set-url appliance "${REMOTE_URL}"
git -C $REPO_DEST push appliance $GIT_BRANCH
# update vault shared/domain value

# # update argocd root-app
# REPO_PATH=$(argocd --core app get prod-argo --output=yaml | yq eval '.spec.source.path')
# REPO_URL=$(argocd --core app get prod-argo --output=yaml | yq eval '.spec.source.repoURL')
# TARGET_REVISION=$(argocd --core app get prod-argo --output=yaml | yq eval '.spec.source.targetRevision')
# if [[ "$REPO_URL" =~ "$DOMAIN" ]]; then
#   echo "CHANGING REPO URL to $NEW_DOMAIN"
#   REPO_URL=$(echo "$REPO_URL" | sed "s|$DOMAIN|$NEW_DOMAIN|g")
#   argocd --core app set prod-argo --repo "$REPO_URL"
#   argocd --core app sync prod-argo
# fi

# sync argocd root-app

# hard-refresh all apps
#for app in $(argocd --core app list -p default -o json | jq -r .[].metadata.name); do argocd --core app get --hard-refresh $app; done
