#!/bin/bash -x
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#
# Expand LVM logical volume and underlying ext4 filesystem

if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi




detect_expandable_devices() {
    local devices=$(lsblk -d -o NAME | grep -E '^(vda|sda)')
    for device in $devices; do
        local size=$(lsblk -d -o SIZE -n /dev/$device)
        local last_partition=$(fdisk -l /dev/$device | grep "^/dev/${device}" | tail -n 1 | awk '{print $1}' | grep -o '[0-9]*$')
        echo "Device: /dev/$device, Size: $size, Last Partition: $last_partition"
        PV=/dev/$device$last_partition
        LV=/dev/ubuntu--vg/ubuntu--lv
        if [ -n $PV ]; then 
            growpart /dev/$device$last_partition
        fi
        if [ -n $PV ]; then
            pvresize $PV
        fi
        if [ -n $LV ]; then
            lvextend -l +100%FREE $LV
        fi
        if [ -n $LV ]; then
            resize2fs $LV
        fi
        # Add logic to check if the device can be expanded
        # For example, check if there is unallocated space
    done
}

detect_expandable_devices
