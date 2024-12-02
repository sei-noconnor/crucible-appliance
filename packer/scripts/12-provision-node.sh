#!/bin/bash

set -e # Exit on any error

K3S_VERSION="v1.29.1+k3s1"
K3S_BASE_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}"

echo "Setting up Ubuntu 22.04 for K3s version ${K3S_VERSION} using manual binaries and k3sup..."

# Update and upgrade system
echo "Updating and upgrading the system..."
sudo apt-get update && sudo apt-get upgrade -y

# Install necessary packages
echo "Installing required packages..."
sudo apt-get install -y curl software-properties-common apt-transport-https ca-certificates

# Disable swap (required for Kubernetes)
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Load necessary kernel modules and configure sysctl
echo "Configuring kernel parameters for Kubernetes..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Download specific K3s binaries
echo "Downloading K3s version ${K3S_VERSION} binaries..."
curl -Lo /usr/local/bin/k3s ${K3S_BASE_URL}/k3s
curl -Lo /usr/local/bin/k3s-agent ${K3S_BASE_URL}/k3s-agent

# Set permissions for binaries
echo "Setting permissions for K3s binaries..."
sudo chmod +x /usr/local/bin/k3s /usr/local/bin/k3s-agent

# Verify binaries
echo "Verifying K3s version..."
k3s --version

# Instructions for adding the node to the cluster using k3sup
echo "To add this node to the cluster using k3sup, run the following command on your local machine:"
echo
echo "  k3sup join --ip <WORKER_NODE_IP> --server-ip <MASTER_NODE_IP> --user <USER> --sudo --k3s-version ${K3S_VERSION}"
echo
echo "Replace <WORKER_NODE_IP>, <MASTER_NODE_IP>, and <USER> with appropriate values."
