#!/bin/bash

VG_NAME="longhorn-vg"
LV_NAME="longhorn-lv"
MOUNT_DIR="/var/lib/longhorn"

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Unmount the logical volume
umount /dev/$VG_NAME/$LV_NAME

# Remove the logical volume
lvremove -y /dev/$VG_NAME/$LV_NAME

# Remove the volume group
vgremove $VG_NAME

# Erase the disk
echo "Erasing disk"
dd if=/dev/zero of=/dev/sdb status=progress bs=512 conv=noerror,sync count=10000

#Remove mount from /etc/fstab
sed -i '/longhorn-vg/d' /etc/fstab

echo "Logical volume and volume group removed successfully."