#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#

# Get vars from appliamce.yaml
source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)

IS_ONLINE=$(curl -s --max-time 5 ifconfig.me >/dev/null && echo true || echo false)
echo "IS_ONLINE: $IS_ONLINE"

# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

# Disable swap for Kubernetes
swapoff -a
sed -i -r 's/(\/swap\.img.*)/#\1/' /etc/fstab
rm -rf /swap.img

######################
###### Update OS #####
######################
if $IS_ONLINE; then
    sudo apt-get update -y && sudo NONINTERACTIVE=1 apt-get dist-upgrade --yes && sudo apt-get autoremove -y
    sudo NONINTERACTIVE=1 apt-get install -y build-essential jq nfs-common sshpass postgresql-client make logrotate git unzip apache2-utils
fi
########################
##### Configure OS #####
########################
# Set hostname 
hostname -b crucible
# Set Timezone EST
sudo timedatectl set-timezone EST
# Increase inodes for asp.net applications
echo fs.inotify.max_user_instances=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
sudo chown -R $SSH_USERNAME:$SSH_USERNAME ~

# Stop multipathd errors in syslog
sudo sed -i '/^blacklist {/,/^}$/d' /etc/multipath.conf
cat <<EOF >> /etc/multipath.conf
blacklist {
    devnode "^sd[a-z0-9]+"
}
blacklist {
    device {
        vendor "IET"
        product "VIRTUAL-DISK"
    }
}
EOF
sudo systemctl restart multipathd

# Customize MOTD and other text for the appliance
chmod -x /etc/update-motd.d/00-header
chmod -x /etc/update-motd.d/10-help-text
sed -i -r 's/(ENABLED=)1/\0/' /etc/default/motd-news
echo "Current Directory is: $PWD"
cp packer/scripts/display-banner /etc/update-motd.d/05-display-banner

# Will need later when we install mkdocs #remove
# sed -i "s/{version}/$APPLIANCE_VERSION/" ~/mkdocs/docs/index.md
echo -e "Crucible Appliance $APPLIANCE_VERSION" > /etc/issue

# setup startup script
echo "Setting Up crucible-appliance startup script $PWD"
yes | cp -rf $PWD/packer/scripts/crucible-appliance-startup.service /etc/systemd/system
yes | cp -rf $PWD/packer/scripts/crucible-appliance-startup.sh /usr/local/bin/
chmod 744 /usr/local/bin/crucible-appliance-startup.sh
chmod 664 /etc/systemd/system/crucible-appliance-startup.service
sudo systemctl daemon-reload
sudo systemctl enable crucible-appliance-startup.service