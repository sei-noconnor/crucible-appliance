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
    export NODE_IP=$(yq ".cluster.$node.ip" ./appliance.yaml)
    export NODE_EXTRA_CONFIG=$(yq ".cluster.$node.extra_config" ./appliance.yaml)
    export NODE_NAME="$node"
    govc vm.clone -vm "$VSPHERE_TEMPLATE" -on=false -c "$NODE_CPUS" -m "$NODE_MEM" -net="$VSPHERE_PORTGROUP" -folder="/$VSPHERE_DATACENTER/vm" -pool="/$VSPHERE_DATACENTER/host/$VSPHERE_CLUSTER/Resources" -ds="$VSPHERE_DATASTORE" -link=true "$NODE_NAME"
    govc vm.customize -vm $NODE_NAME -type=Linux -ip $BASE_IP.$NODE_IP -netmask $(cidr2mask $DEFAULT_NETMASK) -gateway $DEFAULT_GATEWAY -dns-server $DNS_01 -name $NODE_NAME
    govc vm.power -on $NODE_NAME
done





