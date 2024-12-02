#!/bin/bash

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

DIST_DIR=dist/output
name=${1:-crucible-appliance}
echo "Packaging OVF to OVA in $PWD/$DIST_DIR with user: $USER"
echo "we are in $PWD"
ovf=$(ls -1 $DIST_DIR/*.ovf)
mf=$(ls -1 $DIST_DIR/*.mf)
vmdk=$(ls -1 $DIST_DIR/*.vmdk)
# Potential vbox to vmware fix
# sed 's;\(.*<vssd:VirtualSystemType>\).*\(</vssd:VirtualSystemType>\);\1${vmx-14}\2;;' -i nixos-20.09pre-git-x86_64-linux.ovf
# sum=$(sha1sum $ovf | cut -d ' ' -f-1)
# substituteInPlace $mf --replace "SHA1 ($ovf) = .*" "SHA1 ($ovf) = $sum"
echo "Writing OVA, this may take some time."
tar -cvf $DIST_DIR/$name-$BUILD_VERSION.ova -C $ovf $mf $vmdk 
# rm -rf $ova $mf $vmdk