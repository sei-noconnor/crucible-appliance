#!/bin/bash
## This script exports ALL container images from an existing containerd installation, 
## in our case k3s. We save the images in a tar.zst file with nerdctl, nertctl was 
## more reliable then the built in `k3s ctr` command

# Ensure sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo." >&2
    exit 1
fi

# Get vars from appliamce.yaml
source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)

# Defaults
PLATFORM_DEFAULT=linux/amd64
ARCH_DEFAULT=amd64
DIST_DIR_DEFAULT=dist/containers

# Function to display usage information
usage() {
    echo "Usage: $0 [-a|--arch <arch>] [-d|--directory <path>] [-p|--platform <platform>]"
    echo
    echo "Options:"
    echo "  -a, --arch       archatechure of the images (default: $ARCH_DEFAULT)"
    echo "  -d, --directory  Directory to place output  (default: $DIST_DIR_DEFAULT)"
    echo "  -p, --platform   Gateway ip of the cluster  (default: $PLATFORM_DEFAULT)"
    exit 1
}

# Parsing arguments with short and long named variables
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a|--arch) ARCH="$2"; shift ;;
        -d|--directory) DIST_DIR="$2"; shift ;;
        -p|--platform) PLATFORM="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Assign default values if not provided
ARCH="${ARCH:-$ARCH_DEFAULT}"
DIST_DIR="${DIST_DIR:-$DIST_DIR_DEFAULT}"
PLATFORM="${PLATFORM:-$PLATFORM_DEFAULT}"
image_list_file="$DIST_DIR/image-list.txt"

echo
echo
echo "Saving Containers"
echo "=============="
echo "  arch: $ARCH                 "
echo "  directory: $DIST_DIR        "
echo "  platform: $PLATFORM         "
echo "  image list: $image_list_file"

# Make sure the destination directory exists
if [ ! -d $DIST_DIR ]; then
    mkdir -p $DIST_DIR
fi

sudo k3s ctr -n=k8s.io images ls -q | awk '!/sha256/ {print}' > $image_list_file
images=$(cat "${image_list_file}")
sudo k3s ctr -n=k8s.io images export --platform=$PLATFORM $DIST_DIR/images-${ARCH}.tar.zst ${images}
# sudo nerdctl -n=k8s.io --address /run/k3s/containerd/containerd.sock save --platform=$PLATFORM -o $DIST_DIR/images-${ARCH}.tar.zst ${images}