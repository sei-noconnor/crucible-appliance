#!/bin/bash -x
if [[ $# -eq 0 ]]; then

    echo "Usage: $0 <src_dir>"
    exit 1
fi
k3s_cert_dir=/var/lib/rancher/k3s
src_dir=$(realpath $1)
echo "Full SRC PATH is $src_dir"
script_dir=$(dirname "$0")
shift
echo "Sourcing Crucible variables"

source /etc/profile.d/crucible-env.sh
dst_dirs=(
    $(realpath "$script_dir/../argocd/install/cert-manager/kustomize/base/files") \
    $(realpath "$script_dir/../argocd/install/argocd/kustomize/overlays/appliance/files") \
    $(realpath "$script_dir/../argocd/apps/prod-k8s/1-applications/topomojo/kustomize/base/files") \
    $(realpath "$script_dir/../argocd/install/vault/kustomize/base/files") \
    $(realpath "$script_dir/../argocd/apps/prod-k8s/1-applications/mkdocs/kustomize/base/files")
    )

ADMIN_PASS="${ADMIN_PASS:-crucible}"
echo "APPLIANCE_ENVIRONMENT: ${APPLIANCE_ENVIRONMENT}"
if [ "$APPLIANCE_ENVIRONMENT" == APPLIANCE ]; then 
    echo "Script Run on Appliance, copying certs to K3s directory: $k3s_cert_dir"
    if [ ! -d "$k3s_cert_dir" ]; then 
        echo "$ADMIN_PASS" | sudo -S mkdir -p $k3s_cert_dir
    fi
    cat $src_dir/server/tls/intermediate-ca.pem $src_dir/server/tls/root-ca.pem > $src_dir/root-chain.pem
    echo "$ADMIN_PASS" | sudo -S cp -R $src_dir/server $k3s_cert_dir
    echo "$ADMIN_PASS" | sudo -S cp "$src_dir/root-chain.pem" "/usr/local/share/ca-certificates/root-chain.crt"
    echo "$ADMIN_PASS" | sudo -S update-ca-certificates
fi

for dir in "${dst_dirs[@]}"; do
    if [ ! -d $dir ]; then 
        mkdir -p $dir
    fi 
    echo "copying certificates to $dir"
    cat $src_dir/server/tls/intermediate-ca.pem $src_dir/server/tls/root-ca.pem > $src_dir/server/tls/root-chain.pem
    echo "${ADMIN_PASS}" | sudo -S cp -R $src_dir/server/tls/{root-*,intermediate-*} $dir
    sudo chown -R crucible:crucible $dir
done