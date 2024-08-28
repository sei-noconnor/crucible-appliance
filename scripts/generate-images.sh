#!/bin/bash 
echo "Not Implimented Yet!"
exit 0;
pvc_dir=/var/lib/rancher/k3s/storage
certs_dir=/var/lib/rancher/k3s/server/tls 
snapshot_dir=crucible-appliance-$(date -d)
images=$(sudo ctr images ls | awk 'NR>1 {print $1}' | awk -v RS= '{$1=$1}1')"
echo "$ADMIN_PASS" | sudo -S -E bash -c "k3s ctr export /tmp/appliance-snapshotappliance-images.tar $images"
# get all images
sudo ctr images export crucible-appliance-images.tar $(ctr images ls | awk 'NR>1 {print $1}' | awk -v RS= '{$1=$1}1')
# get all pvcs
pvcs=$(kubectl get pvc -A)
# find directory with pvc id tar it up!
### DO THAT!
# copy certs.
### DO THAT!
# Take snapshot 
sudo k3s etcd-snapshot save -name $prefix
# Package it all up to a tar.gz
# Include code repo in package
# include hydration script. 
# K6 test the cluster


