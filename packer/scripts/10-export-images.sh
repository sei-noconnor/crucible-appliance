#!/bin/bash
set -e -x
ARCH=amd64
DIST_DIR=dist/containers
image_list_file='argocd/install/gitea/kustomize/base/files/image-list.txt'
# sudo k3s ctr images prune --all
sudo k3s ctr images ls -q | awk '!/^sha256/ {print}' > $image_list_file
images=$(cat "${image_list_file}")
# xargs -n1 sudo k3s ctr -n=k8s.io images pull <<< "${images}"
if [ ! -d $DIST_DIR ]; then
    mkdir -p $DIST_DIR
fi
sudo k3s ctr -n=k8s.io images export --platform=linux/amd64 $DIST_DIR/images-${ARCH}.tar.zst ${images}
#zstd --no-progress -T0 -16 -f --long=25 $DIST_DIR/images-${ARCH}.tar -o $DIST_DIR/images-${ARCH}.tar.zst

