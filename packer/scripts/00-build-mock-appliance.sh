#!/bin/bash -x
# Change to the current directory and inform the user
echo "Changing to script directory..."
DIR=$(dirname "${BASH_SOURCE[0]}")
MAKEFILE_DIR="$PWD"
OUTPUT_DIR="$MAKEFILE_DIR/dist/output"
echo "MAKEFILE_DIR: $MAKEFILE_DIR"
echo "changing directory to: $DIR"
# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

# Parse target hypervisors into Packer -only option syntax
if [[ $1 != -* ]]; then
    IFS=',' read -ra TARGETS <<< "$1"
    for i in "${TARGETS[@]}"; do
        ONLY_VAR+="$i*,"
    done
    ONLY_VAR=${ONLY_VAR%?}
    shift 1
fi

cd "$DIR" || exit  # Handle potential errors with directory change
SCRIPTS_DIR="${PWD}"

# set all config dirs to absolute paths
PACKER_DIR="$($readlink_cmd ${SCRIPTS_DIR}/../)"

echo "PACKER_DIR: ${PACKER_DIR}"

if git rev-parse --git-dir > /dev/null 2>&1; then
    VERSION_TAG=$(git tag --points-at HEAD)
    GIT_BRANCH=$(git branch --show-current)
    GIT_HASH=$(git rev-parse --short HEAD)
fi

if [ -n "$VERSION_TAG" ]; then
    BUILD_VERSION=$VERSION_TAG
elif [ -n "$GITHUB_PULL_REQUEST" ]; then
    BUILD_VERSION=PR$GITHUB_PULL_REQUEST-$GIT_HASH
elif [ -n "$GIT_HASH" ]; then
    BUILD_VERSION=$GIT_BRANCH-$GIT_HASH
else
    BUILD_VERSION="custom-$(date '+%Y%m%d')"
fi
export VM_NAME="crucible-appliance-$BUILD_VERSION"
# cd $PACKER_DIR/../
# packer init ./packer
echo "Setting VM Name to crucible-appliance-$BUILD_VERSION"
mkdir "$OUTPUT_DIR"
cd "$OUTPUT_DIR"
dd if=/dev/zero bs=1M count=1000 of=$OUTPUT_DIR/$VM_NAME-disk0.vmdk
dd if=/dev/zero bs=1K count=5 of=$OUTPUT_DIR/$VM_NAME.ovf

openssl sha1 *.vmdk *.ovf > $VM_NAME.mf

# if [ -n "$ONLYVAR" ]; then 
#     packer build -only=$ONLY_VAR -var "appliance_version=$BUILD_VERSION" @ ./packer
# else
#     packer build -var "appliance_version=$BUILD_VERSION" -var-file "./packer/vars.auto.pkrvars.hcl" $@ ./packer
# fi