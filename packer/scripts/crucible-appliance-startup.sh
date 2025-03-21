#!/bin/bash

# Logs a message to /var/log/syslog with tag crucible-appliance
# #find crucible related logs
# `sudo cat /var/log/syslog | grep crucible-appliance`
function crucible_log {
    msg="$1"
    echo "$msg"
    tag=crucible-appliance
    logger -i -t "$tag" "$msg"
}

# Check if the IP has changed, if the IP has changed the cluster needs the following: 
# - Reset cluster from snapshot, this recreates the k3s certificates. 
#   It does not re-create the appliance root CA certificates all 
#   CAs and Intermediate CAs will remain the same
# 

msg="Crucible appliance startup script for version: $APPLIANCE_VERSION"
crucible_log "$msg"
source /etc/profile.d/crucible-env.sh
CURRENT_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
APPLIANCE_VERSION=${APPLIANCE_VERSION:-$(cat /etc/appliance_version)}
DOMAIN=${DOMAIN:-crucible.io}
IS_ONLINE=$(curl -s --max-time 5 ifconfig.me >/dev/null && echo true || echo false)

# Expand Volume
sudo /home/${SSH_USERNAME}/crucible-appliance/scripts/expand-all-lvms.sh
#sudo /home/${SSH_USERNAME}/crucible-appliance/scripts/add-longhorn-lvm.sh
# Add coredns entry
sudo /home/${SSH_USERNAME}/crucible-appliance/scripts/add-coredns-entry.sh
#Set if the appliance is on the internet
sudo sed -i "/IS_ONLINE=/c\export IS_ONLINE=\\$IS_ONLINE" /etc/profile.d/crucible-env.sh

if [[ "$APPLIANCE_IP" != "$CURRENT_IP" ]]; then
    
    /home/${SSH_USERNAME}/crucible-appliance/scripts/add-hosts-entry.sh $DOMAIN
    
    # Search for snapshot and do an offline reset
    directory="/var/lib/rancher/k3s/server/db/snapshots"
    prefix=${1:-crucible-appliance}

    files=($(sudo find "$directory" -type f -name "*$prefix*" -print))

    if [ ${#files[@]} -eq 0 ]; then
        msg="No file found with the prefix '$prefix' in '$directory'."
        crucible_log "$msg"
        exit 1
    fi
    filename="${files[0]}"
    
    if [ -n "$filename" ]; then
        echo "You selected: $filename"
        sudo systemctl stop k3s
        sudo k3s server --cluster-reset --cluster-reset-restore-path=$filename
        sudo systemctl daemon-reload
        sudo systemctl start k3s
    fi
    
    echo "CLUSTER RESET!"
    time=15
    echo "Sleeping for $time"
    sleep $time
    K3S_STATUS=$(systemctl is-active k3s)
    if [[ "$K3S_STATUS" == active ]]; then
        sudo sed -i "/APPLIANCE_IP=/d" /etc/profile.d/crucible-env.sh
        echo "export APPLIANCE_IP=$CURRENT_IP" >> /etc/profile.d/crucible-env.sh
    fi
    # Add NodeHosts entry to coredns
    /home/$SSH_USERNAME/crucible-appliance/scripts/add-coredns-hosts-entry.sh -n kube-system -c coredns-custom -r $DOMAIN,cd.$DOMAIN,keystore.$DOMAIN,id.$DOMAIN,code.$DOMAIN -a upsert
    echo "Waiting for Cluster deployments 'Status: Avaialble' This may cause a timeout."
    k3s kubectl wait deployment \
    --all \
    --for=condition=available \
    --all-namespaces=true \
    --timeout=1m
else 
    msg="Crucible Appliance IPs match starting normally"
    crucible_log "$msg"
fi
# Unseal the vault on startup 
crucible_log "Attempting to unseal the vault"
/home/${SSH_USERNAME}/crucible-appliance/crucible-appliance/packer/scripts/09-unseal-vault.sh

image_count=$(sudo k3s ctr images ls | awk 'END{print NR'})
if [[ ! "$IS_ONLINE" && -f "$DIST_DIR/containers/images-amd64.tar.zst" ]]; then
    sudo /home/${SSH_USERNAME}/crucible-appliance/crucible-appliance/packer/10-import-images.sh
fi

