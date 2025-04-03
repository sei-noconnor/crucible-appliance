#!/bin/bash -x

# This script installs and configures a K3s cluster on multiple nodes using the provided appliance.yaml configuration file.
# It performs the following steps:
# 1. Checks if 'yq' is installed, exits if not found.
# 2. Exports variables from appliance.yaml.
# 3. Creates a registries.yaml file with Docker mirror configurations.
# 4. Sets up environment variables for vSphere and node configurations.
# 5. Copies the K3s node token to the appropriate directory with correct permissions.
# 6. Generates a cmds.sh script to configure sudoers, install K3s, and set up kubeconfig.
# 7. Uploads necessary scripts and files to each node using govc.
# 8. Optionally runs the cmds.sh script on each node to complete the setup.


# Ensure yq is installed
if ! command -v yq &> /dev/null
then
    echo "yq could not be found, please install it to proceed."
    exit
fi

# Check if the number of replicas is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_replicas>"
    exit 1
fi

NUMBER_OF_REPLICAS=$1

if [ -f ./appliance.yaml ]; then
    export $(yq '.vars | to_entries | .[] | "\(.key | upcase)=\(.value)"' ./appliance.yaml | xargs)
fi

# Increase volume replicas to the specified number
for vol in $(kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath="{.items[*].metadata.name}"); do
    kubectl patch volumes.longhorn.io "$vol" -n longhorn-system --type='merge' -p "{\"spec\": {\"numberOfReplicas\": $NUMBER_OF_REPLICAS}}"
done


