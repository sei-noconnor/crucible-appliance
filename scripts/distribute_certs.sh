#!/bin/bash 
# Check if an image list file is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <src_dir>"
    exit 1
fi
k3s_cert_dir=/var/lib/rancher/k3s
src_dir=$1
shift
dst_dirs=('argocd/apps/cert-manager/kustomize/base/files')

if [ $ENVIRONMENT == APPLIANCE ]; then 
    echo "Script Run on Appliance, copying"
    echo "$ADMIN_PASS" | sudo -S cp -R $src_dir $k3s_cert_dir
fi

for i in "${dst_dirs[@]}"; do
    echo "copying certificates to $i"
    cp -R $src_dir $i
done