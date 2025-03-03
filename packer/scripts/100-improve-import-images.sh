#!/bin/bash
set -e -x

# Default values
ARCH=amd64
DIST_DIR=dist/containers
TEMP_DIR=.
image_file=$DIST_DIR/images-amd64.tar.zst

# Usage function
usage() {
    echo "Usage: $0 [-a|--arch <architecture>] [-d|--dist_dir <distribution_directory>] [-t|--temp_dir <temp_directory>] [-i|--image_file <image_file>] [-h|--help]"
    echo "  -a, --arch        Set the architecture (default: amd64)"
    echo "  -d, --dist_dir    Set the distribution directory (default: dist/containers)"
    echo "  -t, --temp_dir    Set the temporary directory (default: /tmp)"
    echo "  -i, --image_file  Set the image file (default: dist/containers/images-amd64.tar.zst)"
    echo "  -h, --help        Display this help message"
    echo ""
    echo "Example: $0 -a arm64 -d /custom/dist -t /custom/tmp -i /custom/dist/images-arm64.tar.zst"
    exit 1
}

# Parse options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a|--arch) ARCH="$2"; shift ;;
        -d|--dist_dir) DIST_DIR="$2"; shift ;;
        -t|--temp_dir) TEMP_DIR="$2"; shift ;;
        -i|--image_file) image_file="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Ensure the temp directory exists
mkdir -p "$TEMP_DIR"

# Extract index.json and manifest.json from the tar.zst file
zstdcat "$image_file" | tar -C "$TEMP_DIR" -xvf - 'index.json' 'manifest.json' 'oci-layout'

# Verify that the files were extracted
if [[ ! -f "$TEMP_DIR/manifest.json" || ! -f "$TEMP_DIR/index.json" ]]; then
    echo "Error: Required files (manifest.json or index.json) not found in the archive."
    exit 1
fi

# Generate file image list
file_images=$(jq -r '.[].RepoTags[]' "$TEMP_DIR/manifest.json" | uniq | sort)
echo "$file_images" > "$TEMP_DIR/file_images.txt"

# Get loaded images from k3s ctr
loaded_images=$(sudo k3s ctr -n=k8s.io images ls -q | awk '!/sha256/ {print}' | uniq | sort)
echo "$loaded_images" > "$TEMP_DIR/loaded_images.txt"

# Find out which images are not loaded
diff -u "$TEMP_DIR/file_images.txt" "$TEMP_DIR/loaded_images.txt" | grep -E "^\+" | cut -c 2- > "$TEMP_DIR/images_to_load.txt"

# From images_to_load.txt generate a list of files to extract from index.json
jq -r --argfile images_to_load "$TEMP_DIR/images_to_load.txt" '.[] | select(.RepoTags[] as $rt | $images_to_load | index($rt)) | .Config.Digest' "$TEMP_DIR/manifest.json" > "$TEMP_DIR/digests_to_extract.txt"