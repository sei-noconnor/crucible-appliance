#!/bin/bash -x
# This script destroys a cluster of virtual machines defined in the appliance.yaml file.
# 
# Prerequisites:
# - yq must be installed and available in the system's PATH.
# - The appliance.yaml file must be present in the current directory.
# - Environment variables VSPHERE_USER, VSPHERE_PASSWORD, and VSPHERE_SERVER must be defined in the appliance.yaml file.
#
# Steps:
# 1. Check if yq is installed. If not, print an error message and exit.
# 2. If appliance.yaml exists, export its variables to the environment.
# 3. Set the GOVC_URL and GOVC_INSECURE environment variables for govc.
# 4. Extract the list of node names from the appliance.yaml file.
# 5. Loop through each node name and destroy the corresponding virtual machine using govc.


# Ensure yq is installed
if ! command -v yq &> /dev/null
then
    echo "yq could not be found, please install it to proceed."
    exit
fi

if [ -f ./appliance.yaml ]; then
    export $(yq '.vars | to_entries | .[] | "\(.key | upcase)=\(.value)"' ./appliance.yaml | xargs)
fi
export GOVC_URL="https://${VSPHERE_USER}:${VSPHERE_PASSWORD}@${VSPHERE_SERVER}"
export GOVC_INSECURE=1

export NODES=$(yq '.cluster | to_entries | .[] | .key' ./appliance.yaml | xargs)

# Clone the nodes
for node in $NODES; do
    govc vm.destroy $node
done
