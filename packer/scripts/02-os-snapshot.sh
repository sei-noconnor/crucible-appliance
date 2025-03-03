#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#

# Default values
SNAPSHOT_NAME="base-cluster"
DEFAULT_SAVE_LOCATION="/var/lib/rancher/k3s/server/db/snapshots"
SAVE_LOCATION=""
COMPRESS=true

# Usage function
usage() {
    echo "Usage: $0 [-n|--name <snapshot_name>] [-l|--location <save_location>] [-c|--compress] [-h|--help]"
    echo "  -n, --name        Set the snapshot name (default: base-cluster)"
    echo "  -l, --location    Set the save location (default: /var/lib/rancher/k3s/server/db/snapshots)"
    echo "  -c, --compress    Compress the snapshot"
    echo "  -h, --help        Display this help message"
    echo ""
    echo "Example: $0 -n custom-snapshot -l /custom/location -c"
    exit 1
}

# Parse options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--name) SNAPSHOT_NAME="$2"; shift ;;
        -l|--location) SAVE_LOCATION="$2"; shift ;;
        -c|--compress) COMPRESS=true ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Get vars from appliance.yaml
source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)

# Take base cluster snapshot
echo "Sleeping for 20 seconds for snapshot"
sleep 20

if [ "$COMPRESS" = true ]; then
    k3s etcd-snapshot save --snapshot-compress --name "$SNAPSHOT_NAME" --dir "$DEFAULT_SAVE_LOCATION"
else
    k3s etcd-snapshot save --name "$SNAPSHOT_NAME" --dir "$DEFAULT_SAVE_LOCATION"
fi

# Move the snapshot to the specified location if provided
if [ -n "$SAVE_LOCATION" ]; then
    mv "$DEFAULT_SAVE_LOCATION/$SNAPSHOT_NAME"*.db "$SAVE_LOCATION"
    echo "Snapshot moved to $SAVE_LOCATION"
fi