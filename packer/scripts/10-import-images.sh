#!/bin/bash
set -e -x
ARCH=amd64
DIST_DIR=/home/crucible/crucible-appliance/dist/containers
image_file=/home/crucible/crucible-appliance/dist/containers/images-amd64.tar.zst
sudo k3s ctr -n=k8s.io images import --platform=linux/amd64 ${image_file}
#zstd --no-progress -T0 -16 -f --long=25 $DIST_DIR/images-${ARCH}.tar -o $DIST_DIR/images-${ARCH}.tar.zst
