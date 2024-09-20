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
if [[ $APPLIANCE_IP != $CURRENT_IP ]]; then
    # Add hosts Entry 
    if grep -q "crucible.local" /etc/hosts; then
        # If it doesn't exist, append it to the hosts file
        tmp_file=/tmp/temp-$(openssl rand -hex 4).txt
        sudo awk "/crucible.local/ {print '$CURRENT_IP    $DOMAIN'; next} 1" /etc/hosts > $tmp_file && yes | sudo mv -f $tmp_file /etc/hosts
        msg="Entry update in host file: /etc/hosts '$CURRENT_IP   $DOMAIN'"
        crucible_log "$msg"
    else
        msg="Entry doesn't exists in hosts file.'$CURRENT_IP    $DOMAIN'"
        sudo echo "$CURRENT_IP    crucible.local" >> /etc/hosts
        crucible_log "$msg"
    fi
    # Add NodeHosts entry to coredns
    ./scripts/add-coredns-entry.sh $CURRENT_IP $DOMAIN

    #Search for snapshot and do an offline restore
    make offline-reset
else 
    msg="Crucible Appliance IPs match starting normally"
    crucible_log "$msg"
fi


