#!/bin/bash -x
# This script sets up and mounts a Logical Volume Manager (LVM) for Longhorn.
# It performs the following steps:
# 1. Detects new unused disks that meet a minimum size requirement (10GB).
# 2. Creates a volume group (VG) named "longhorn-vg" if it doesn't exist.
# 3. Adds detected new disks to the volume group.
# 4. Creates a logical volume (LV) named "longhorn-lv" if it doesn't exist.
# 5. Formats the logical volume with ext4 filesystem if necessary.
# 6. Checks if the mount point (/var/lib/longhorn) is empty and moves contents to a temporary directory if not.
# 7. Mounts the logical volume to the mount point.
# 8. Restores files from the temporary directory to the mount point if necessary.
# 9. Outputs a message indicating the completion of the Longhorn LVM setup and mounting process.

set -e

# Default values
VG_NAME="longhorn-vg"
LV_NAME="longhorn-lv"
MOUNT_POINT="/var/lib/longhorn"
TEMP_DIR=$(mktemp -d)
MIN_DISK_SIZE_MB=10240  # Minimum disk size for LVM (10GB)

# Usage information
usage() {
    echo "Usage: $0 [-v|--vg-name <volume_group_name>] [-l|--lv-name <logical_volume_name>] [-m|--mount-point <mount_point>] [-s|--min-disk-size <size_in_mb>]"
    echo "Options:"
    echo "  -v, --vg-name        Name of the volume group (default: longhorn-vg)"
    echo "  -l, --lv-name        Name of the logical volume (default: longhorn-lv)"
    echo "  -m, --mount-point    Mount point for the logical volume (default: /var/lib/longhorn)"
    echo "  -s, --min-disk-size  Minimum disk size in MB for LVM (default: 10240)"
    echo "  -h, --help           Display this help message"
    echo "Example: $0 --vg-name my-vg --lv-name my-lv --mount-point /mnt/my_mount --min-disk-size 20480"
    exit 1
}

# Parse options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--vg-name) VG_NAME="$2"; shift ;;
        -l|--lv-name) LV_NAME="$2"; shift ;;
        -m|--mount-point) MOUNT_POINT="$2"; shift ;;
        -s|--min-disk-size) MIN_DISK_SIZE_MB="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

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
