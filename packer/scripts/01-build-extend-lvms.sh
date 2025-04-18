#!/bin/bash
# Auto-LVM Creator for Disks >10GB
# Detects new disks >10GB, creates LVM, and mounts at specified path

# Configuration
MIN_DISK_SIZE_GB=10               # Minimum disk size to consider (in GB)
MOUNT_POINT="/var/lib/longhorn"               # Change to your desired mount point
VG_NAME="longhornvg"                  # Volume Group name
LV_NAME="longhornlv"                  # Logical Volume name
FILESYSTEM="ext4"                  # xfs or ext4
LV_SIZE="100%FREE"                # Use 100% of VG space or specify like "10G"

# Check root
[ "$(id -u)" -ne 0 ] && { echo "This script must be run as root" >&2; exit 1; }

# Check required commands
for cmd in lsblk pvcreate vgcreate lvcreate mkfs.$FILESYSTEM awk; do
    if ! command -v $cmd >/dev/null; then
        echo "Error: Required command '$cmd' not found" >&2
        exit 1
    fi
done

# Create mount point if needed
mkdir -p "$MOUNT_POINT"

# Function to convert human sizes to GB
size_to_gb() {
    local size=$1
    if [[ $size == *G ]]; then
        echo "${size%G}"
    elif [[ $size == *T ]]; then
        echo "${size%T} * 1024" | bc
    elif [[ $size == *M ]]; then
        echo "scale=2; ${size%M} / 1024" | bc
    else
        echo "scale=2; $size / 1073741824" | bc  # Convert bytes to GB
    fi
}

# Function to create LVM and mount
setup_disk() {
    local disk=$1
    
    echo "Processing $disk..."
    
    # Create Physical Volume
    if ! pvcreate "$disk"; then
        echo "Failed to create physical volume on $disk" >&2
        return 1
    fi
    
    # Create Volume Group or extend if exists
    if ! vgdisplay "$VG_NAME" >/dev/null 2>&1; then
        if ! vgcreate "$VG_NAME" "$disk"; then
            echo "Failed to create volume group $VG_NAME" >&2
            return 1
        fi
    else
        if ! vgextend "$VG_NAME" "$disk"; then
            echo "Failed to extend volume group $VG_NAME" >&2
            return 1
        fi
    fi
    
    # Create Logical Volume (only if doesn't exist)
    if ! lvdisplay "/dev/$VG_NAME/$LV_NAME" >/dev/null 2>&1; then
        if ! lvcreate -n "$LV_NAME" -l "$LV_SIZE" "$VG_NAME"; then
            echo "Failed to create logical volume $LV_NAME" >&2
            return 1
        fi
        
        # Create filesystem
        if ! mkfs.$FILESYSTEM "/dev/$VG_NAME/$LV_NAME"; then
            echo "Failed to create $FILESYSTEM filesystem" >&2
            return 1
        fi
    fi
    
    # Mount and add to fstab
    if ! grep -q "/dev/$VG_NAME/$LV_NAME" /etc/fstab; then
        echo "Adding to /etc/fstab..."
        echo "/dev/$VG_NAME/$LV_NAME $MOUNT_POINT $FILESYSTEM defaults 0 0" >> /etc/fstab
    fi
    
    # Mount all filesystems
    mount -a
    
    echo "Successfully configured $disk"
    echo "Mounted at: $MOUNT_POINT"
    df -h "$MOUNT_POINT"
}

# Main script
echo "Detecting new disks >${MIN_DISK_SIZE_GB}GB..."

# Find all suitable disks
NEW_DISKS=()
while read -r disk size; do
    size_gb=$(size_to_gb "$size")
    
    # Compare sizes (using bc for floating point)
    if (( $(echo "$size_gb > $MIN_DISK_SIZE_GB" | bc -l) )); then
        # Additional checks - no partitions, not in LVM, not mounted
        if ! lsblk "$disk" | grep -q part && \
           ! pvs "$disk" >/dev/null 2>&1 && \
           ! findmnt -n -o SOURCE | grep -q "^$disk"; then
            NEW_DISKS+=("$disk ($size)")
        fi
    fi
done < <(lsblk -o NAME,SIZE -n -d | grep -E '^sd[a-z]|^vd[a-z]|^xvd[a-z]|^nvme[0-9]n[0-9]' | awk '{print "/dev/"$1, $2}')

if [ ${#NEW_DISKS[@]} -eq 0 ]; then
    echo "No new unpartitioned disks >${MIN_DISK_SIZE_GB}GB found"
    exit 0
fi

echo "Found suitable disks:"
printf '  %s\n' "${NEW_DISKS[@]}"

# Process each new disk
for disk_info in "${NEW_DISKS[@]}"; do
    disk=${disk_info% (*)}
    size=${disk_info#* (}
    size=${size%)}
    
    read -p "Configure $disk ($size) for LVM? [y/N] " choice
    case "$choice" in
        y|Y) 
            # Double-check disk meets size requirement
            size_gb=$(size_to_gb "$size")
            if (( $(echo "$size_gb > $MIN_DISK_SIZE_GB" | bc -l) )); then
                setup_disk "$disk"
            else
                echo "Disk $disk is now showing as <${MIN_DISK_SIZE_GB}GB, skipping"
            fi
            ;;
        *) echo "Skipping $disk" ;;
    esac
done

echo "Current LVM status:"
vgs
lvs
pvs

echo "Mount status:"
df -h "$MOUNT_POINT" 2>/dev/null || echo "No filesystem mounted at $MOUNT_POINT"