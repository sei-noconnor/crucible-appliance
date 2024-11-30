#!/bin/bash
# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

# set all config dirs to absolute paths
REPO_DIR="/home/crucible/crucible-appliance"
REPO_DEST="/tmp/crucible-appliance"
GITEA_SERVER="${2:-https://$DOMAIN/gitea}"
CMT_MSG=${1:-}
GITEA_ORG=fortress-manifests
TIMEOUT=30
INTERVAL=2

echo "REPO_DIR: ${REPO_DIR}"
if [ ! -d $REPO_DEST ]; then
  echo "Repo Destination: $REPO_DEST does not exist. Creating."
  mkdir -p $REPO_DEST
fi
echo "Copying repo from $REPO_DIR to $REPO_DEST"
rsync -avP \
    --exclude dist/containers \
    --exclude dist/tools \
    --exclude dist/debian \
    $REPO_DIR/ $REPO_DEST/

GIT_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)
echo "REPO Destination: $REPO_DEST"
echo
echo "Making replacements in $REPO_DEST on Branch: $GIT_BRANCH"

find $REPO_DEST -name "Application.yaml" -exec sed -i "s/file:\/\/\/crucible-repo\/crucible-appliance/https:\/\/crucible.local\/gitea\/${GITEA_ORG}\/crucible-appliance.git/g" {} \;
find $REPO_DEST -name "*.yaml" -exec sed -i "s/https:\/\/github.com\/sei-noconnor/https:\/\/crucible.local\/gitea\/${GITEA_ORG}/g" {} \;
find $REPO_DEST -name "*.yaml" -exec sed -i "s/targetRevision: HEAD/targetRevision: ${GIT_BRANCH}/g" {} \;
find $REPO_DEST -name "*.yaml" -exec sed -i "s/revision: HEAD/revision: ${GIT_BRANCH}/g" {} \;
find $REPO_DEST -name "*.json" -exec sed -i "s/\"project_branch\" : \"HEAD\"/\"project_branch\" : \"${GIT_BRANCH}\"/g" {} \;

# allow root-ca.pem to be commited.
echo "!**/*/root-ca.pem" >> .gitignore
# allow root-ca.key to be commited. This is bad, use a vault!
echo "!**/*/root-ca.key" >> .gitignore

git -C $REPO_DEST add "**/*.pem"
git -C $REPO_DEST add "**/*.key"
git -C $REPO_DEST add --all
git -C $REPO_DEST user.name="admin" -c user.email="admin@${DOMAIN}" commit -m "${CMT_MSG:-Generic repo-sync commit, see diff}"

# Function to check if the server is up
is_server_up() {
    curl -s --head --request GET "$GITEA_SERVER" | grep "200" > /dev/null
}

# Wait for the server to be up
wait_for_server() {
    start_time=$(date +%s)
    while ! is_server_up; do
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if (( elapsed_time >= TIMEOUT )); then
            echo "Timeout reached. Gitea server is not up."
            return 1
        fi
        echo "Waiting for Gitea server to be up..."
        sleep $INTERVAL
    done
    echo "Gitea server is up."
    return 0
}

if wait_for_server; then
    echo "Running commands that depend on the Gitea server..."
    # Add commands here that require the Gitea server
    echo "Pushing to Git server..."
    git -C $REPO_DEST remote remove origin
    REMOTE_URL="https://administrator:crucible@${DOMAIN}/gitea/${GITEA_ORG}/crucible-appliance.git"
    git -C $REPO_DEST remote add appliance "${REMOTE_URL}" 2>/dev/null || git remote set-url appliance "${REMOTE_URL}"
    git -C $REPO_DEST push appliance $GIT_BRANCH -f
else
    echo "Gitea server not up, not pushing changes, yet"
    exit 0
fi


