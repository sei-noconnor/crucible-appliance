#!/bin/bash

set -e

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