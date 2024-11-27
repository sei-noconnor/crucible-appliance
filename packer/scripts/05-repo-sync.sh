#!/bin/bash 
# Change to the current directory and inform the user
echo "Changing to script directory..."
DIR=$(dirname "${BASH_SOURCE[0]}")
echo "changing directory to: $DIR"
# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

cd "$DIR" || exit  # Handle potential errors with directory change
SCRIPTS_DIR="${PWD}"

# set all config dirs to absolute paths
CHARTS_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../dist/charts)"
INSTALL_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../argocd/install)"
DIST_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../dist)"
APPS_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../argocd/apps/)"
REPO_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../../)"
REPO_DEST="/tmp/crucible-appliance"

echo "CHARTS_DIR: ${CHARTS_DIR}"
echo "INSTALL_DIR: ${INSTALL_DIR}"
echo "REPO_DIR: ${REPO_DIR}"
echo "Creating directory $REPO_DEST"
mkdir -p $REPO_DEST
echo "Copying repo from $REPO_DIR to $REPO_DEST"
rsync -avP $REPO_DIR/ $REPO_DEST/
GIT_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)
echo "REPO Destination: $REPO_DEST"
cd $REPO_DEST
find . -name "Application.yaml" -exec sed -i "s/main/${GIT_BRANCH}/g" {} \;
# allow root-ca.pem to be commited.
echo "!**/*/root-ca.pem" >> .gitignore
# allow root-ca.key to be commited. This is bad, use a vault!
echo "!**/*/root-ca.key" >> .gitignore
git checkout $GIT_BRANCH
git  add -u 
git add "**/*.pem"
git add "**/*.key"
git -c user.name="admin" -c user.email="admin@crucible.local" commit -m "Appliance Init, it's your repo now!" 
REMOTE_URL="https://administrator:crucible@crucible.local/gitea/fortress-manifests/crucible-appliance.git"
git remote add appliance "${REMOTE_URL}" 2>/dev/null || git remote set-url appliance "${REMOTE_URL}"
git push appliance $GIT_BRANCH -f