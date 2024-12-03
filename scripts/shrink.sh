#!/bin/bash 
sudo journalctl --vacuum-size=300M
sudo logrotate /etc/logrotate.conf
sudo apt-get -y autoremove 
sudo apt-get -y clean
sudo rm -rf /var/cache/api/archives/*
# Search for files larger then 50M in tmp
files=`/tmp -type f -size +50M -exec du -h {} \; | sort -n`
for f in ${files[@]}; do
    rm $f
done
# Remove swap
rm -rf /swap.img
# Find largest files and remove (typically a large swap)
# Maybe a little too optomistic removed container images
# files=`sudo find / -mount -type f -size +100M -exec du -h {} \; | sort -n`
# for f in ${files[@]}; do
#     rm $f
# done
# echo "removing unused container images"
# sudo k3s ctr images prune --all
echo "Removing temporary git repo"
sudo rm -rf /tmp/crucible-appliance
echo "Removing dist directories that have been uploaded to gitea"
#sudo rm -rf /home/crucible/crucible-appliance/dist/{charts,deb,generic}
echo "Zeroing Disk, This may take some time"
sudo dd if=/dev/zero of=~/fill.dd bs=1M
sudo rm -rf ~/fill.dd

echo "Shrinking Hard Drive COMPLETE!"
