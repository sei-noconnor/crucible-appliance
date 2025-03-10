#!/bin/bash
# This script adds a new node to the Kubernetes cluster.
#
# It ensures that sshpass is installed, parses command line arguments to set
# node configuration, and performs the necessary steps to add the node to the
# cluster, including cloning the VM, configuring the network, and installing K3s.
#
# Usage:
#   cluster-add-node.sh [-t|--type <controller|worker>] [-n|--name <node-name>] [-c|--cpus <cpus>] [-m|--memory <memory>] [-i|--ip <ip-address>] [-g|--gateway <gateway>] [-k|--netmask <netmask>] [--deploy] [--install]
#
# Options:
#   -t, --type      Node type (controller or worker). Default is worker.
#   -n, --name      Node name. Required.
#   -c, --cpus      Number of CPUs. Default is 2.
#   -m, --memory    Memory size in MB. Default is 4096.
#   -i, --ip        IP address. Required.
#   -g, --gateway   Gateway. Required.
#   -k, --netmask   Netmask. Required.
#   --deploy        Deploy the node without cloning the VM. Default is false.
#   --install       Install the cluster. Default is false.
#   -h, --help      Display this help message.
#
# Example:
#   cluster-add-node.sh -t worker -n node01 -c 4 -m 8192 -i 192.168.1.100 -g 192.168.1.1 -k 255.255.255.0 --deploy --install
#
# The script performs the following steps:
# 1. Ensures sshpass is installed.
# 2. Parses command line arguments to set node configuration.
# 3. Checks if required parameters (node name, IP, gateway, netmask) are provided.
# 4. Adds the node to the cluster by cloning the VM and configuring the network.
# 5. Installs K3s on the node.

# Ensure sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "sshpass could not be found, installing..."
    sudo apt-get update && sudo apt-get install -y sshpass
fi

# Default values
NODE_TYPE="worker"
NODE_NAME=""
NODE_CPUS=2
NODE_MEM=4096
NODE_IP=""
NODE_GATEWAY=""
NODE_NETMASK="255.255.255.0"
DEPLOY=false
INSTALL=false

#  Usage function
usage() {
    echo "Usage: $0 [-t|--type <controller|worker>] [-n|--name <node-name>] [-c|--cpus <cpus>] [-m|--memory <memory>] [-i|--ip <ip-address>] [-g|--gateway <gateway>] [-k|--netmask <netmask>] [--deploy] [--install]"
    echo "  -t, --type      Node type (controller or worker). Default is worker."
    echo "  -n, --name      Node name. Required."
    echo "  -c, --cpus      Number of CPUs. Default is 2."
    echo "  -m, --memory    Memory size in MB. Default is 4096."
    echo "  -i, --ip        IP address. Required."
    echo "  -g, --gateway   Gateway. Required."
    echo "  -k, --netmask   Netmask. Required."
    echo "  --deploy        Deploy the node without cloning the VM. Default is false."
    echo "  --install       Install the cluster. Default is false."
    echo "  -h, --help      Display this help message."
    echo ""
    echo "Example:"
    echo "  $0 -t worker -n node01 -c 4 -m 8192 -i 192.168.1.100 -g 192.168.1.1 -k 255.255.255.0 --deploy --install"
    exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--type) NODE_TYPE="$2"; shift ;;
        -n|--name) NODE_NAME="$2"; shift ;;
        -c|--cpus) NODE_CPUS="$2"; shift ;;
        -m|--memory) NODE_MEM="$2"; shift ;;
        -i|--ip) NODE_IP="$2"; shift ;;
        -g|--gateway) NODE_GATEWAY="$2"; shift ;;
        -k|--netmask) NODE_NETMASK="$2"; shift ;;
        --deploy) DEPLOY=true ;;
        --install) INSTALL=true ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Check if node name, IP, gateway, and netmask are provided
if [ -z "$NODE_NAME" ] || [ -z "$NODE_IP" ] || [ -z "$NODE_GATEWAY" ] || [ -z "$NODE_NETMASK" ]; then
    echo "Error: Node name, IP address, gateway, and netmask are required."
    usage
fi

# Add node to the cluster
echo "Adding $NODE_TYPE node to the cluster..."
echo "Node Name: $NODE_NAME"
echo "CPUs: $NODE_CPUS"
echo "Memory: $NODE_MEM MB"
echo "IP Address: $NODE_IP"
echo "Gateway: $NODE_GATEWAY"
echo "Netmask: $NODE_NETMASK"

if [ "$DEPLOY" = true ]; then
    # Example command to add the node (replace with actual implementation)
    govc vm.clone -vm "$VSPHERE_TEMPLATE" -on=false -c "$NODE_CPUS" -m "$NODE_MEM" -net="$VSPHERE_PORTGROUP" -folder="/$VSPHERE_DATACENTER/vm" -pool="/$VSPHERE_DATACENTER/host/$VSPHERE_CLUSTER/Resources" -ds="$VSPHERE_DATASTORE" -link=true "$NODE_NAME"
    govc vm.customize -vm $NODE_NAME -type=Linux -ip $NODE_IP -netmask $NODE_NETMASK -gateway $NODE_GATEWAY -dns-server $DNS_01 -name $NODE_NAME
    govc vm.power -on $NODE_NAME
    # Wait for the VM to be accessible
    echo "Waiting for $NODE_NAME to be accessible..."
    while ! ping -c 1 -W 1 "$NODE_IP" &> /dev/null; do
        echo -n "."
        sleep 5
    done

    echo "$NODE_NAME is now accessible. waiting for reboot..."
    while ping -c 1 -W 1 "$NODE_IP" &> /dev/null; do
        echo -n "."
        sleep 5
    done

    echo "Waiting for $NODE_NAME to finish rebooting..."
    while ! ping -c 1 -W 1 "$NODE_IP" &> /dev/null; do
        echo -n "."
        sleep 5
    done
    echo "I am le tired, take a NAP"
    sleep 10
    echo "Fire the missles!"
fi

if [ "$INSTALL" = true ]; then
    # copy node token 
    sudo cp -f /var/lib/rancher/k3s/server/node-token ./dist/ssl/server/tls/node-token
    # install K3s on the node
    sshpass -p$SUDO_PASSWORD scp -o StrictHostKeyChecking=no ./packer/scripts/01-add-volume.sh $SUDO_USERNAME@$NODE_IP:/home/$SUDO_USERNAME/01-add-volume.sh
    sshpass -p$SUDO_PASSWORD scp -o StrictHostKeyChecking=no ./scripts/cluster-node-prep.sh $SUDO_USERNAME@$NODE_IP:/home/$SUDO_USERNAME/cluster-node-prep.sh
    sshpass -p$SUDO_PASSWORD scp -o StrictHostKeyChecking=no ./dist/ssl/server/tls/node-token $SUDO_USERNAME@$NODE_IP:/home/$SUDO_USERNAME/node-token
    sshpass -p$SUDO_PASSWORD scp -o StrictHostKeyChecking=no ./dist/generic/k3s-install.sh $SUDO_USERNAME@$NODE_IP:/home/$SUDO_USERNAME/k3s-install.sh
    sshpass -p$SUDO_PASSWORD scp -o StrictHostKeyChecking=no ./registries.yaml $SUDO_USERNAME@$NODE_IP:/home/$SUDO_USERNAME/registries.yaml
    
    sshpass -p$SUDO_PASSWORD ssh -o StrictHostKeyChecking=no $SUDO_USERNAME@$NODE_IP << EOF
chmod 0711 /home/$SUDO_USERNAME/01-add-volume.sh
chmod 0711 /home/$SUDO_USERNAME/k3s-install.sh
chmod 0711 /home/$SUDO_USERNAME/cluster-node-prep.sh
chmod 0611 /home/$SUDO_USERNAME/registries.yaml
chmod 0600 /home/$SUDO_USERNAME/node-token
EOF

    # Run K3s installer over ssh

    if [[ $NODE_TYPE == controller ]]; then
        sshpass -p$SUDO_PASSWORD ssh -o StrictHostKeyChecking=no $SUDO_USERNAME@$NODE_IP << EOF
sudo /home/$SUDO_USERNAME/01-add-volume.sh
echo "Preparing the node"
sudo /home/$SUDO_USERNAME/cluster-node-prep.sh
# Install K3s
sudo mkdir -p /etc/rancher/k3s
mkdir -p ~/.kube
sudo cp /home/$SUDO_USERNAME/registries.yaml > /etc/rancher/k3s/registries.yaml
echo "Installing k3s"
INSTALL_K3S_VERSION="v1.31.3+k3s1" K3S_KUBECONFIG_MODE="644" INSTALL_K3S_SKIP_DOWNLOAD=true \
INSTALL_K3S_EXEC="server --server https://${DOMAIN:-crucible.io}:6443 --disable traefik \
--embedded-registry --etcd-expose-metrics  --prefer-bundled-bin --tls-san ${DOMAIN:-crucible.io} \
--token-file /home/crucible/node-token" /home/crucible/k3s-install.sh
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i "s/default/crucible-appliance/g" ~/.kube/config
sed -i "s/127.0.0.1/${DOMAIN}/g" ~/.kube/config
sudo chown -R $SUDO_USERNAME:$SUDO_USERNAME ~/.kube
chmod go-r ~/.kube/config
EOF

    else
        sshpass -p$SUDO_PASSWORD ssh -o StrictHostKeyChecking=no $SUDO_USERNAME@$NODE_IP << EOF
sudo /home/$SUDO_USERNAME/01-add-volume.sh
echo "Preparing the node"
sudo /home/$SUDO_USERNAME/node-prep.sh
# Install K3s
sudo mkdir -p /etc/rancher/k3s
mkdir -p ~/.kube
sudo cp /home/$SUDO_USERNAME/registries.yaml > /etc/rancher/k3s/registries.yaml

INSTALL_K3S_VERSION="v1.31.3+k3s1" K3S_KUBECONFIG_MODE="644" INSTALL_K3S_SKIP_DOWNLOAD=true \
INSTALL_K3S_EXEC="agent --server https://${DOMAIN:-crucible.io}:6443 --disable traefik \
--embedded-registry --etcd-expose-metrics  --prefer-bundled-bin --tls-san ${DOMAIN:-crucible.io} \
--token-file /home/crucible/node-token" /home/crucible/k3s-install.sh
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i "s/default/crucible-appliance/g" ~/.kube/config
sed -i "s/127.0.0.1/${DOMAIN}/g" ~/.kube/config
sudo chown -R $SUDO_USERNAME:$SUDO_USERNAME ~/.kube
chmod go-r ~/.kube/config
EOF
    fi

    echo "$NODE_TYPE node $NODE_NAME added to the cluster successfully."
fi