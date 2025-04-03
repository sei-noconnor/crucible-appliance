#!/bin/bash -x
#
# This script is used to expand a cluster by cloning and configuring virtual machines (VMs) based on the configuration
# specified in the appliance.yaml file. It ensures that the required tool 'yq' is installed, reads configuration values
# from the YAML file, and performs the following tasks:
# # Prerequisites:
#   - yq must be installed to parse YAML files.
#
# The script performs the following steps:
# 1. Checks if 'yq' is installed and exits if not found.
# 2. Loads variables from the appliance.yaml file into environment variables.
# 3. Sets up the GOVC_URL and GOVC_INSECURE environment variables for vSphere operations.
# 4. Defines functions to convert subnet masks to CIDR notation and vice versa.
# 5. Calculates the BASE_IP from the DEFAULT_NETWORK.
# 6. Iterates over the nodes defined in the appliance.yaml file and performs the following for each node:
#    - Clones the VM from a specified template.
#    - Creates an additional disk for the VM.
#    - Customizes the VM with the specified IP, netmask, gateway, DNS server, and name.
#    - Powers on the VM.

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

# Function to convert subnet mask to CIDR notation
mask2cidr() {
    local x=${1##*255.}
    set -- ${x//./ }
    local a=$(( (${1:-0} * 8) + (${2:-0} * 4) + (${3:-0} * 2) + (${4:-0} * 1) ))
    echo $(( 32 - a ))
}

# Function to convert CIDR notation to subnet mask
cidr2mask() {
    local i
    local mask=""
    local cidr=$1
    for ((i=0; i<4; i++)); do
        if [ $cidr -ge 8 ]; then
            mask+=255
            cidr=$((cidr - 8))
        else
            mask+=$((256 - 2**(8-cidr)))
            cidr=0
        fi
        [ $i -lt 3 ] && mask+=.
    done
    echo $mask
}

# Calculate BASE_IP
export BASE_IP=$(echo $DEFAULT_NETWORK |cut -d"." -f1-3)
export NODES=$(yq '.cluster | to_entries | .[] | .key' ./appliance.yaml | xargs)

# Clone the nodes
for node in $NODES; do
    export NODE_CPUS=$(yq ".cluster.$node.cpus" ./appliance.yaml)
    export NODE_MEM=$(yq ".cluster.$node.memory" ./appliance.yaml)
    export NODE_IP=$BASE_IP.$(yq ".cluster.$node.ip" ./appliance.yaml)
    export NODE_EXTRA_CONFIG=$(yq ".cluster.$node.extra_config" ./appliance.yaml)
    export NODE_NAME="$node"
    # TODO: get type of node ctrl or wrkr
    if [[ $node == *"ctrl"* ]]; then
        NODE_TYPE="controller"
    else
        NODE_TYPE="worker"
    fi
    ./scripts/cluster-add-node.sh -t $NODE_TYPE -n $NODE_NAME -c $NODE_CPUS -m $NODE_MEM -i $NODE_IP -g $DEFAULT_GATEWAY -k $(cidr2mask $DEFAULT_NETMASK) --deploy
done