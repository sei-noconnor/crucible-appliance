#!/bin/bash -x

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
# - Add host entry for curcible.local with new IP 
# - Add NodeHost entry for crucible.local in cluster coredns 
# - Reset cluster from snapshot, this recreates the k3s certificates. 
#   It does not re-create the appliance root CA certificates all 
#   CAs and Intermediate CAs will remain the same
# 
msg="Crucible appliance startup script for version: $APPLIANCE_VERSION"
crucible_log "$msg"
CURRENT_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
APPLIANCE_VERSION=${APPLIANCE_VERSION:-$(cat /etc/appliance_version)}
DOMAIN=${DOMAIN:-crucible.local}

if [[ $APPLIANCE_IP != $CURRENT_IP ]]; then
    # Delete old entry
    sudo sed -i "/$DOMAIN/d" /etc/hosts
    msg="Entry being added in hosts file. entry: '$CURRENT_IP    $DOMAIN'"
    # Append it to the hosts file
    tmp_file=/tmp/temp-$(openssl rand -hex 4).txt
    sudo echo "$CURRENT_IP   $DOMAIN" >> /etc/hosts
    msg="Entry update in host file: /etc/hosts '$CURRENT_IP   $DOMAIN'"
    crucible_log "$msg"

    # Add NodeHosts entry to coredns
    /home/crucible/crucible-appliance/scripts/add-coredns-entry.sh $CURRENT_IP $DOMAIN

#     # Search for snapshot and do an offline reset
#     directory="/var/lib/rancher/k3s/server/db/snapshots"
#     prefix=${1:-crucible-appliance}

#     files=($(sudo find "$directory" -type f -name "*$prefix*" -print))

#     if [ ${#files[@]} -eq 0 ]; then
#         echo "No file found with the prefix '$prefix' in '$directory'."
#         exit 1
#     fi
#     filename="${files[0]}"
    
#     if [ -n "$filename" ]; then
#         echo "You selected: $filename"
#         sudo systemctl stop k3s
#         sudo k3s server --cluster-reset --cluster-reset-restore-path=$filename
#         sudo systemctl daemon-reload
#         sudo systemctl start k3s
#     fi
    
#     echo "CLUSTER RESET!"
#     time=15
#     echo "Sleeping for $time"
#     sleep $time
#     echo "Waiting for Cluster deployments 'Status: Avaialble' This may cause a timeout."
#     kubectl wait deployment \
#     --all \
#     --for=condition=Available \
#     --all-namespaces=true \
#     --timeout=5m
else 
    msg="Crucible Appliance IPs match starting normally"
    crucible_log "$msg"
fi


