#!/bin/bash -x

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
