#!/bin/bash -x
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.

GITEA_ADMIN_PASSWORD="postgres"
# CURL_OPTS=( --silent --header "accept: application/json" --header "Content-Type: application/json" )
CURL_OPTS=( --header "accept: application/json" --header "Content-Type: application/json" )
KEY_NAME="crucible-appliance-argo-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)"
USER_TOKEN=$( curl "${CURL_OPTS[@]}" \
    --user administrator:$GITEA_ADMIN_PASSWORD \
    --request POST "https://crucible.local/gitea/api/v1/users/administrator/tokens" \
    --data "{\"name\": \"$KEY_NAME\",\"scopes\":[\"write:admin\",\"write:organization\"]}" | jq -r '.sha1'
)

REPO_DIR=~/crucible-appliance-argo
REPO_DEST=/tmp/crucible-appliance-argo

# Change to the current directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Set git user vars
git config --global user.name "Crucible Administrator"
git config --global user.email "administrator@crucible.local"

# Create Crucible-docs organization
curl "${CURL_OPTS[@]}" \
  --request POST "https://crucible.local/gitea/api/v1/orgs?access_token=$USER_TOKEN" \
  --data @- <<EOF
  {
    "description": "",
    "email": "",
    "full_name": "",
    "location": "",
    "repo_admin_change_team_access": true,
    "username": "crucible",
    "visibility": "public",
    "website": ""
  }
EOF

# Create repo
curl "${CURL_OPTS[@]}" \
    --request POST "https://crucible.local/gitea/api/v1/orgs/crucible/repos?access_token=$USER_TOKEN" \
    --data @- <<EOF
{
  "auto_init": true,
  "default_branch": "",
  "description": "",
  "gitignores": "",
  "issue_labels": "",
  "license": "",
  "name": "crucible-appliance-argo",
  "object_format_name": "sha1",
  "private": false,
  "readme": "",
  "template": false,
  "trust_model": "default"
}
EOF

echo "$ADMIN_PASS" | sudo -S -E bash -c "rm -rf /tmp/crucible-appliance-argo"
cp -R $REPO_DIR $REPO_DEST
cd $REPO_DEST
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
find . -name "*.yaml" -exec sed -i 's/file:\/\/\/tmp\/argo/https:\/\/crucible.local\/gitea\/crucible\/crucible-appliance-argo.git/g' {} \;
find . -name "*.yaml" -exec sed -i 's/path: apps/path: argocd\/apps/g' {} \;

git -C $REPO_DEST add -u 
git -C $REPO_DEST commit -m "update repo urls"
git -C $REPO_DEST remote remove appliance
git -C $REPO_DEST remote add appliance https://administrator:$GITEA_ADMIN_PASSWORD@crucible.local/gitea/crucible/crucible-appliance-argo.git
git -C $REPO_DEST push -u appliance --all -f

argocd --core app set apps --source-position 1 --repo https://crucible.local/gitea/crucible/crucible-appliance-argo.git --path argocd/install/argocd/kustomize/overlay/appliance --ref $GIT_BRANCH

