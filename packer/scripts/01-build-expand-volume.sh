#!/bin/bash

# This script expands all physical and logical volumes on the system.
# It first resizes all physical volumes to use any additional space available on the devices.
# Then, it checks for free space in each volume group and expands the logical volumes accordingly.
# Finally, it resizes the filesystem on each logical volume to use the newly allocated space.

# The script performs the following steps:
# 1. Retrieves all physical volumes using the `pvs` command.
# 2. Iterates over each physical volume and resizes it using the `pvresize` command if the device size has changed.
# 3. Retrieves all logical volumes using the `lvs` command.
# 4. For each logical volume, it checks the free space available in the corresponding volume group.
# 5. If there is free space available, it expands the logical volume using the `lvextend` command.
# 6. Depending on the filesystem type (ext4 or xfs), it resizes the filesystem using `resize2fs` or `xfs_growfs`.
# 7. If the filesystem type is unsupported, it skips the resize operation for that logical volume.
# 8. Prints messages indicating the progress and completion of the LVM expansion process.

set -e
# This script has no parameters 

# Get all physical volumes
PVS=$(pvs --noheadings -o pv_name)

for PV in $PVS; do
    DEVICE=$(basename $PV)
    
    # Check if the device size has changed
    if [[ -b $PV ]]; then
        pvresize $PV
    fi
done

# Get all logical volumes
LVS=$(lvs --noheadings -o lv_path)

for LV in $LVS; do
    VG=$(lvs --noheadings -o vg_name $LV | awk '{print $1}')
    FREE_SPACE=$(vgs --noheadings -o free --units m $VG | awk '{print $1}' | sed 's/m//')
    
    if (( $(echo "$FREE_SPACE > 0" | bc -l) )); then
        echo "Expanding $LV in volume group $VG by $FREE_SPACE MB"
        lvextend -L+${FREE_SPACE}M $LV
        
        # Check filesystem type
        FS_TYPE=$(blkid -o value -s TYPE $LV)
        if [[ "$FS_TYPE" == "ext4" ]]; then
            resize2fs $LV
        elif [[ "$FS_TYPE" == "xfs" ]]; then
            xfs_growfs $LV
        else
            echo "Unsupported filesystem type $FS_TYPE on $LV, skipping resize."
        fi
    else
        echo "No free space available in volume group $VG for $LV."
    fi
done

echo "LVM expansion process completed."