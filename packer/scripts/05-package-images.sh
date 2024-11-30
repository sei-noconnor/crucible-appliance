#!/bin/bash
set -e -x
ARCH=amd64
DIST_DIR=dist/containers

image_file='argocd/install/gitea/kustomize/base/files/image-list.txt'
images=$(cat "${image_file}")
# xargs -n1 sudo k3s ctr -n=k8s.io images pull <<< "${images}"
if [ ! -d $DIST_DIR ]; then
    mkdir -p $DIST_DIR
fi
sudo k3s ctr -n=k8s.io images export $DIST_DIR/images-${ARCH}.tar ${images}
zstd --no-progress -T0 -16 -f --long=25 $DIST_DIR/images-${ARCH}.tar -o $DIST_DIR/images-${ARCH}.tar.zst
pigz -v -c $DIST_DIR/images-${ARCH}.tar > $DIST_DIR/images-${ARCH}.tar.gz
