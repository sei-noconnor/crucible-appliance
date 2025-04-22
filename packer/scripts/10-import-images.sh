#!/bin/bash
set -e -x
ARCH=amd64
PLATFORM=linux/$ARCH
DIST_DIR=dist/containers
for image_file in $DIST_DIR/*.tar.zst; do
    # image_name=$(tar -I zstd -xf ${image_file} manifest.json -O | jq -r '.[0].RepoTags[0]')
    # if sudo k3s ctr -n=k8s.io images list | grep -q "${image_name}"; then
    #     echo "Image ${image_name} already exists, skipping import."
    #     continue
    # fi
    sudo k3s ctr -n=k8s.io images import --platform=$PLATFORM ${image_file}
done
#zstd --no-progress -T0 -16 -f --long=25 $DIST_DIR/images-${ARCH}.tar -o $DIST_DIR/images-${ARCH}.tar.zst
