#!/bin/bash

# Variables
VG_NAME="longhorn-vg"
LV_NAME="longhorn-lv"
MOUNT_DIR="/var/lib/longhorn"
LV_SIZE="100%FREE"  # Adjust this if you want a specific size

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Function to detect available, unallocated, physical disks within /dev/sdb to /dev/sdc range
function detect_available_disks {
    echo "Detecting available physical disks in the range /dev/sdb to /dev/sdf..."
    AVAILABLE_DISKS=()

    # Loop through the specific disk range
    for disk in /dev/sd{b..c}; do
        # Check if the disk physically exists and meets criteria
        if [ -b "$disk" ] && \
           fdisk -l "$disk" 2>/dev/null | grep -q "^Disk $disk:" && \
           ! pvs --noheadings -o pv_name | grep -q "$disk" && \
           ! lsblk -ln -o NAME "$disk" | grep -E "^${disk#/dev/}[1-9]"; then
            AVAILABLE_DISKS+=("$disk")
        fi
    done

    # Check if any available disks were found
    if [ ${#AVAILABLE_DISKS[@]} -eq 0 ]; then
        echo "No unallocated available physical disks found in the specified range."
        exit 1
    fi
}

# Run the disk detection function
detect_available_disks

# Display available disks
echo "Available physical disks:"
for disk in "${AVAILABLE_DISKS[@]}"; do
    echo "$disk"
done

# Select the first available disk (modify if you want to choose a specific one)
DISK="${AVAILABLE_DISKS[0]}"
echo "Selected disk: $DISK"

# Create a new Physical Volume (PV)
echo "Creating physical volume on $DISK..."
pvcreate "$DISK"

# Create a Volume Group (VG)
echo "Creating volume group $VG_NAME..."
vgcreate "$VG_NAME" "$DISK"

# Create a Logical Volume (LV)
echo "Creating logical volume $LV_NAME with size $LV_SIZE..."
lvcreate -l "$LV_SIZE" -n "$LV_NAME" "$VG_NAME"

# Format the LV with ext4 filesystem
echo "Formatting logical volume $LV_NAME with ext4 filesystem..."
yes "N"| mkfs.ext4 -n "/dev/$VG_NAME/$LV_NAME"

# Create the mount directory if it doesn't exist
if [ ! -d "$MOUNT_DIR" ]; then
    echo "Creating mount directory $MOUNT_DIR..."
    mkdir -p "$MOUNT_DIR"
fi

if [ -d "$MOUNT_DIR" ] && [ "$(ls -A $DIR)" ]; then
    echo "Directory is not empty."
    echo "REFUSING TO MOUNT NEW DISK, $MOUNT_DIR IS NOT EMPTY, MOUNTING WOULD KILL THE CLUSTER"
    exit 0
else
    echo "Directory is empty."
    # Mount the logical volume
    echo "Mounting /dev/$VG_NAME/$LV_NAME to $MOUNT_DIR..."
    mount "/dev/$VG_NAME/$LV_NAME" "$MOUNT_DIR"

    # Add to /etc/fstab for persistent mount
    echo "Updating /etc/fstab for persistent mount..."
    echo "/dev/$VG_NAME/$LV_NAME $MOUNT_DIR ext4 defaults 0 0" >> /etc/fstab

    echo "Done! Logical volume $LV_NAME is mounted on $MOUNT_DIR."
fi

