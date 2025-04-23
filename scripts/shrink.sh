#!/bin/bash 
sudo journalctl --vacuum-size=0M
sudo logrotate /etc/logrotate.conf
sudo apt-get -y autoremove 
sudo apt-get -y clean
sudo rm -rf /var/cache/apt/archives/*
rm -rf /tmp/* 
# Remove swap
rm -rf /swap.img


# echo "removing all container images"
# sudo k3s ctr images ls -q | xargs sudo k3s ctr image rm 
# echo "Removing dist directories"
sudo rm -rf /home/crucible/crucible-appliance/dist/{charts,deb,generic}
sudo k3s-killall.sh
trap 'echo "Command interrupted. Cleaning up..."; sudo rm -rf ~/fill.dd' EXIT
echo "Zeroing Disk, This may take some time"
sudo dd if=/dev/zero of=~/fill.dd bs=1M
sudo rm -rf ~/fill.dd
echo "Shrinking Hard Drive COMPLETE!"
