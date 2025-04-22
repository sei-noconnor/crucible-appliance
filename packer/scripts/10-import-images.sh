#!/bin/bash
set -e -x
ARCH=amd64
PLATFORM=linux/$ARCH
DIST_DIR=dist/containers
if [ ! -d "$DIST_DIR" ]; then
    echo "Directory $DIST_DIR does not exist. Not importing images."
    exit 0
fi
    

for image_file in $DIST_DIR/*.tar.zst; do
    # Try to extract image name from the tar.zst file
    # image_name=$(tar -I zstd -xf ${image_file} manifest.json -O | jq -r '.[0].RepoTags[0]')
    # if sudo k3s ctr -n=k8s.io images list | grep -q "${image_name}"; then
    #     echo "Image ${image_name} already exists, skipping import."
    #     continue
    # fi
    sudo k3s ctr -n=k8s.io images import --platform=$PLATFORM ${image_file}
done
#zstd --no-progress -T0 -16 -f --long=25 $DIST_DIR/images-${ARCH}.tar -o $DIST_DIR/images-${ARCH}.tar.zst
