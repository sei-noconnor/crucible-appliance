#!/bin/bash
set -e -x
ARCH=amd64
DIST_DIR=dist/containers
image_file=$DIST_DIR/images-amd64.tar.zst
sudo k3s ctr -n=k8s.io images import --platform=linux/amd64 ${image_file}
#zstd --no-progress -T0 -16 -f --long=25 $DIST_DIR/images-${ARCH}.tar -o $DIST_DIR/images-${ARCH}.tar.zst
