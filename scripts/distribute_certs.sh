#!/bin/bash 
# Check if an image list file is provided
if [[ $# -eq 0 ]]; then

    echo "Usage: $0 <src_dir>"
    exit 1
fi
k3s_cert_dir=$(realpath /var/lib/rancher/k3s)
src_dir=$(realpath $1)
echo "Full SRC PATH is $src_dir"
script_dir=$(dirname "$0")
shift
dst_dirs=$(realpath "$script_dir/../argocd/apps/cert-manager/kustomize/base/files")

if [ $ENVIRONMENT == APPLIANCE ]; then 
    echo "Script Run on Appliance, copying certs to K3s directory"
    if [ ! -d "$k3s_cert_dir" ]; then 
        echo "$ADMIN_PASS" | sudo -S mkdir -p $k3s_cert_dir
    fi
    cat $src_dir/intermediate-ca.pem $src_dir/root-ca.pem > $src_dir/root-chain.pem
    echo "$ADMIN_PASS" | sudo -S cp -R $src_dir $k3s_cert_dir
    echo "$ADMIN_PASS" | sudo -S cp "$src_dir/root-chain.pem" "/usr/local/share/ca-certificates/root-chain.crt"
    echo "$ADMIN_PASS" | sudo -S update-ca-certificates
fi

for dir in "${dst_dirs[@]}"; do
    if [ ! -d $dir ]; then 
        mkdir -p $dir
    fi 
    echo "copying certificates to $dir"
    cat $src_dir/intermediate-ca.pem $src_dir/root-ca.pem > $src_dir/root-chain.pem
    cp -R $src_dir/{root-*,intermediate-*} $dir
done