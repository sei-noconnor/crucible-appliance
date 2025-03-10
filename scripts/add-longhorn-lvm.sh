#!/bin/bash -x

set -e

VG_NAME="longhorn-vg"
LV_NAME="longhorn-lv"
MOUNT_POINT="/var/lib/longhorn"
TEMP_DIR="mktemp -d"
MIN_DISK_SIZE_MB=10240  # Minimum disk size for LVM (10GB)

# Detect new unused disks
NEW_DISKS=()
for DISK in $(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}'); do
    DISK_SIZE=$(lsblk -b -d -n -o SIZE "$DISK")
    DISK_SIZE_MB=$((DISK_SIZE / 1024 / 1024))
    if [[ $DISK_SIZE_MB -ge $MIN_DISK_SIZE_MB ]] && ! pvs | grep -q "$DISK"; then
        NEW_DISKS+=("$DISK")
    fi
done

if [[ ${#NEW_DISKS[@]} -eq 0 ]]; then
    echo "No new unused disks detected that meet the minimum size requirement."
    exit 0
fi

echo "New unused disks detected: ${NEW_DISKS[*]}"

# Create a volume group if it doesn't exist
if ! vgs | grep -q "$VG_NAME"; then
    vgcreate "$VG_NAME" "${NEW_DISKS[0]}"
    NEW_DISKS=("${NEW_DISKS[@]:1}")
fi

# Add new disks to the volume group
if [[ ${#NEW_DISKS[@]} -gt 0 ]]; then
    for DISK in "${NEW_DISKS[@]}"; do
        vgextend "$VG_NAME" "$DISK"
    done
fi

# Create a logical volume if it doesn't exist
if ! lvs | grep -q "$LV_NAME"; then
    lvcreate -l 100%FREE -n "$LV_NAME" "$VG_NAME"
fi

# Format if necessary
LV_PATH="/dev/$VG_NAME/$LV_NAME"
if ! blkid "$LV_PATH"; then
    mkfs.ext4 "$LV_PATH"
fi

# Check if mount point is empty
if [[ -n "$(ls -A $MOUNT_POINT 2>/dev/null)" ]]; then
    echo "$MOUNT_POINT is not empty, moving contents to $TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    mv "$MOUNT_POINT"/* "$TEMP_DIR"/
fi

# Mount the new volume
mount "$LV_PATH" "$MOUNT_POINT"

# Restore files if necessary
if [[ -d "$TEMP_DIR" ]]; then
    mv "$TEMP_DIR"/* "$MOUNT_POINT"/
    rmdir "$TEMP_DIR"
fi

echo "Longhorn LVM setup and mounting completed."
