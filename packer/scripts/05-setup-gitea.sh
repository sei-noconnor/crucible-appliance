#!/bin/bash -x
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
ADMIN_PASS=${ADMIN_PASS:-crucible}
# CURL_OPTS=( --silent --header "accept: application/json" --header "Content-Type: application/json" )
CURL_OPTS=( --user "administrator:${ADMIN_PASS}" --header "accept: application/json" --header "Content-Type: application/json" )
echo "Waiting for gitea to become available"
timeout 60s bash -c 'while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' https://onprem.imcite-phl.net/gitea)" != "200" ]]; do sleep 5; done'

REPO_DIR=/home/crucible/crucible-appliance
REPO_DEST=/tmp/crucible-appliance
GITEA_ORG=fortress-manifests

# Create Organization
curl "${CURL_OPTS[@]}" \
  --request POST "https://onprem.imcite-phl.net/gitea/api/v1/orgs" \
  --data @- <<EOF
  {
    "repo_admin_change_team_access": true,
    "username": "${GITEA_ORG}"
  }
EOF

# Create repo
curl "${CURL_OPTS[@]}" \
    --request POST "https://onprem.imcite-phl.net/gitea/api/v1/orgs/${GITEA_ORG}/repos" \
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

GIT_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)

# Replace Repo URL to cluster gitea
find $REPO_DEST -name "Application.yaml" -exec sed -i "s/file:\/\/\/crucible-repo\/crucible-appliance/https:\/\/onprem.imcite-phl.net\/gitea\/${GITEA_ORG}\/crucible-appliance.git/g" {} \;
find $REPO_DEST -name "*.yaml" -exec sed -i "s/https:\/\/github.com\/sei-noconnor/https:\/\/onprem.imcite-phl.net\/gitea\/${GITEA_ORG}/g" {} \;
find $REPO_DEST -name "*.yaml" -exec sed -i "s/targetRevision: HEAD/targetRevision: ${GIT_BRANCH}/g" {} \;
find $REPO_DEST -name "*.yaml" -exec sed -i "s/revision: HEAD/revision: ${GIT_BRANCH}/g" {} \;
find $REPO_DEST -name "*.json" -exec sed -i "s/\"project_branch\" : \"HEAD\"/\"project_branch\" : \"${GIT_BRANCH}\"/g" {} \;

# Modify app path slightly
git -C $REPO_DEST add "**/*.pem"
git -C $REPO_DEST add "**/*.key"
git -C $REPO_DEST add --all
git -C $REPO_DEST commit -m "update repo urls and add certificates"
git -C $REPO_DEST remote remove appliance
git -C $REPO_DEST remote remove origin
git -C $REPO_DEST remote add appliance https://administrator:${ADMIN_PASS}@onprem.imcite-phl.net/gitea/${GITEA_ORG}/crucible-appliance.git
git -C $REPO_DEST push -u appliance --mirror -f || true