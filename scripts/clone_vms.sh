#!/bin/bash

# Ensure govc is installed
if ! command -v govc &> /dev/null
then
    echo "govc could not be found, please install it to proceed."
    exit
fi

# Load environment variables from appliance.yaml
if [ -f ./appliance.yaml ]; then
    export $(yq '.vars | to_entries | .[] | "\(.key | upcase)=\(.value)"' ./appliance.yaml | xargs)
fi

# Default values
BASE_NAME="crucible-vm"
TEMPLATE_NAME="crucible-template"
DATASTORE="datastore1"
NETWORK="VM Network"
FOLDER="vm_folder"
RESOURCE_POOL="resource_pool"
NUM_VMS=6

# Set govc connection variables
export GOVC_URL="https://${VSPHERE_USER}:${VSPHERE_PASSWORD}@${VSPHERE_SERVER}"
export GOVC_INSECURE=1

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -b, --base-name       Base name for the VMs (default: crucible-vm)"
    echo "  -t, --template-name   Name of the template to clone from (default: crucible-template)"
    echo "  -d, --datastore       Datastore to use (default: datastore1)"
    echo "  -n, --network         Network to connect the VMs to (default: VM Network)"
    echo "  -f, --folder          Folder to place the VMs in (default: vm_folder)"
    echo "  -r, --resource-pool   Resource pool to use (default: resource_pool)"
    echo "  -c, --num-vms         Number of VMs to clone (default: 6)"
    exit 1
}

# Parse parameters
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b|--base-name) BASE_NAME="$2"; shift ;;
        -t|--template-name) TEMPLATE_NAME="$2"; shift ;;
        -d|--datastore) DATASTORE="$2"; shift ;;
        -n|--network) NETWORK="$2"; shift ;;
        -f|--folder) FOLDER="$2"; shift ;;
        -r|--resource-pool) RESOURCE_POOL="$2"; shift ;;
        -c|--num-vms) NUM_VMS="$2"; shift ;;
        *) usage ;;
    esac
    shift
done

# Clone VMs
for i in $(seq 1 $NUM_VMS); do
    VM_NAME="${BASE_NAME}-0${i}"
    VM_IP="192.168.1.$((160 + i))"
    govc vm.clone -vm=$TEMPLATE_NAME -ds=$DATASTORE -folder=$FOLDER -pool=$RESOURCE_POOL -on=false -link=true -force=true $VM_NAME
    govc vm.customize -vm $VM_NAME -type=Linux -ip $VM_IP -netmask 255.255.255.0 -gateway 192.168.1.1 -dns-server 192.168.1.153 -name $VM_NAME
    govc vm.power -on $VM_NAME
done

echo "Cloning and customization of VMs completed."

# Sample usage
# bash /home/crucible/crucible-appliance/scripts/clone_vms.sh --base-name crucible-crtrl --template-name t-ubuntu2204 --datastore my-datastore --network "192.168.1.0" --folder my-folder --resource-pool my-resource-pool --num-vms 6
