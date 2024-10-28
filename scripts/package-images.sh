#!/bin/bash
set -e -x

cd $(dirname $0)/..

. ./scripts/version.sh

airgap_image_file='scripts/airgap/image-list.txt'
images=$(cat "${airgap_image_file}")
xargs -n1 docker pull <<< "${images}"
docker save ${images} -o dist/artifacts/k3s-airgap-images-${ARCH}.tar
zstd --no-progress -T0 -16 -f --long=25 dist/artifacts/k3s-airgap-images-${ARCH}.tar -o dist/artifacts/k3s-airgap-images-${ARCH}.tar.zst
pigz -v -c dist/artifacts/k3s-airgap-images-${ARCH}.tar > dist/artifacts/k3s-airgap-images-${ARCH}.tar.gz
if [ ${ARCH} = amd64 ]; then
  cp "${airgap_image_file}" dist/artifacts/k3s-images.txt
fi