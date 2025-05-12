#!/bin/bash
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

# source variables from appliance.yaml
if [ -f ./appliance.yaml ]; then
  source ./packer/scripts/lib/functions.sh
  yaml_to_env "./appliance.yaml"
fi

# Parse arguments
SKIP_TERRAFORM=false
SKIP_ANSIBLE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-terraform) SKIP_TERRAFORM=true ;;
        --skip-ansible) SKIP_ANSIBLE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

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
echo "$NODES"

# Terraform steps
if [ "$SKIP_TERRAFORM" = false ]; then
    ./scripts/update_tfvars.py
    terraform -chdir=./devops/terraform init
    terraform -chdir=./devops/terraform plan
    terraform -chdir=./devops/terraform apply -auto-approve
    log_pretty "Cluster expansion completed successfully. Preparing for Ansible configuration" "green"
else
    log_pretty "Skipping Terraform steps as per user request" "yellow"
fi

# Ansible configuration
if [ "$SKIP_ANSIBLE" = false ]; then
    log_pretty "Sleeping 10 Seconds" "green"
    sleep 10
    repo_dir=${PWD}
    cd devops/terraform
    ansible-playbook -i inventory.yaml deploy.yaml --extra-vars "ansible_sudo_pass=${ADMIN_PASS}"
    cd $repo_dir
    log_pretty "Ansible Configuration Finished" "green"
else
    log_pretty "Skipping Ansible configuration as per user request" "yellow"
fi
