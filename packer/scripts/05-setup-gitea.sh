#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
ADMIN_PASS=${ADMIN_PASS:-crucible}
# CURL_OPTS=( --silent --header "accept: application/json" --header "Content-Type: application/json" )
CURL_OPTS=( --user "administrator:${ADMIN_PASS}" --header "accept: application/json" --header "Content-Type: application/json" )

timeout 5m bash -c 'while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' https://crucible.local/gitea)" != "200" ]]; do sleep 5; done'
sleep 5


REPO_DIR=/home/crucible/crucible-appliance
REPO_DEST=/tmp/crucible-appliance

# Change to the current directory
cd ${REPO_DEST}

# Set git user vars
git config user.name "Crucible Administrator"
git config user.email "administrator@crucible.local"

# Create crucible organization
curl "${CURL_OPTS[@]}" \
  --request POST "https://crucible.local/gitea/api/v1/orgs" \
  --data @- <<EOF
  {
    "repo_admin_change_team_access": true,
    "username": "crucible"
  }
EOF

# Create repo
curl "${CURL_OPTS[@]}" \
    --request POST "https://crucible.local/gitea/api/v1/orgs/crucible/repos" \
    --data @- <<EOF
{
  "auto_init": true,
  "default_branch": "",
  "description": "",
  "gitignores": "",
  "issue_labels": "",
  "license": "",
  "name": "crucible-appliance",
  "object_format_name": "sha1",
  "private": false,
  "readme": "",
  "template": false,
  "trust_model": "default"
}
EOF


cd /tmp/crucible-appliance

GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Replace Repo URL to cluster gitea
find . -name "Application.yaml" -exec sed -i 's/file:\/\/\/crucible-repo\/crucible-appliance/https:\/\/crucible.local\/gitea\/crucible\/crucible-appliance.git/g' {} \;
# Modify app path slightly

git -C $REPO_DEST add --all
git -C $REPO_DEST add "**/*.pem"
git -C $REPO_DEST add "**/*.key"
git -C $REPO_DEST commit -m "update repo urls and add certificates"
git -C $REPO_DEST remote remove appliance
git -C $REPO_DEST remote add appliance https://administrator:${ADMIN_PASS}@crucible.local/gitea/crucible/crucible-appliance.git
git -C $REPO_DEST push -u appliance --mirror -f || true

# echo "Creating argocd app to gitea source control on branch ${GIT_BRANCH}"
# kubectl apply -f $REPO_DEST/argocd/install/argocd/Application.yaml
# argocd --core app create argocd \
#   --repo https://crucible.local/gitea/crucible/crucible-appliance-argo.git \
#   --path argocd/install/argocd/kustomize/overlays/appliance \
#   --ref "${GIT_BRANCH}" \
#   --dest-server https://kubernetes.default.svc \
#   --sync-policy auto \
#   --upsert \
#   --sync-option Prune=true 
  
  
  
# echo "Updating argo app of apps to source control on branch ${GIT_BRANCH:-main}"

#kubectl apply -f $REPO_DEST/argocd/apps/Application.yaml

# argocd --core app create apps \
#   --repo https://crucible.local/gitea/crucible/crucible-appliance-argo.git \
#   --path argocd/apps \
#   --ref "${GIT_BRANCH:-main}" \
#   --dest-server https://kubernetes.default.svc \
#   --sync-policy auto \
#   --sync-option Prune=true \
#   --upsert
