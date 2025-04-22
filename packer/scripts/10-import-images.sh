#!/bin/bash
set -e -x
ARCH=amd64
DIST_DIR=dist/containers
for image_file in $DIST_DIR/*.tar.zst; do
    sudo k3s ctr -n=k8s.io images import --platform=linux/amd64 ${image_file}
done
#zstd --no-progress -T0 -16 -f --long=25 $DIST_DIR/images-${ARCH}.tar -o $DIST_DIR/images-${ARCH}.tar.zst
