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
    if [ ! -d "$k3s_cert_dir" ]; then 
        echo "$ADMIN_PASS" | sudo -S mkdir -p $k3s_cert_dir
    fi
    echo "$ADMIN_PASS" | sudo -S cp -R $src_dir $k3s_cert_dir
    echo "$ADMIN_PASS" | sudo -S cp $src_dir/root-chain.pem $sdt_dir/root-chain.crt
    echo "$ADMIN_PASS" | sudo -S update-ca-certificates
fi

for dir in "${dst_dirs[@]}"; do
    if [ ! -d $dir ]; then 
        mkdir -p $i
    fi 
    echo "copying certificates to $i"
    cat $src_dir/intermediate-ca.pem $src_dir/root-ca.pem > $src_dir/root-chain.pem
    cp -R $src_dir/{root*,intermediate*} $i
done