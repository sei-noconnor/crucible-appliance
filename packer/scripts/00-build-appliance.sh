#!/bin/bash -x
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
packer init ./packer
packer build -var "appliance_version=$BUILD_VERSION" $@ ./packer