#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#

###############
#### VARS #####
###############
PACKER_DIR="/Users/noconnor/source/crucible/Crucible.Appliance.Argo/packer"
APPLIANCE_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')

######################
###### Update OS #####
######################
sudo apt update -y && sudo NEEDRESTART_MODE=a apt-get dist-upgrade --yes && sudo apt autoremove -y

################################
##### Install Dependencies #####
################################
# Install Apt Packages
apt-get install -y jq nfs-common postgresql-client

# Install K3s
sudo mkdir -p /etc/rancher/k3s
mkdir -p ~/.kube
sudo echo "nameserver 10.0.1.1" >> /etc/rancher/k3s/resolv.conf
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.29.1+k3s1" K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="server --disable traefik --disable servicelb --embedded-registry --etcd-expose-metrics --cluster-init --prefer-bundled-bin" sh - 
sudo -u $SSH_USERNAME mkdir ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's/default/crucible-appliance/g' ~/.kube/config
sed -i "s/127.0.0.1/$APPLIANCE_IP/g" ~/.kube/config
chown $SSH_USERNAME:$SSH_USERNAME ~/.kube/config
chmod go-r ~/.kube/config

# Install Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm -rf ./get_helm.sh

# Install K9s
curl -sLo k9s_linux_amd64.deb "https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.deb"
sudo NEEDRESTART_MODE=a apt install --yes ./k9s_linux_amd64.deb
#tar -xvzf k9s.tar.gz
#sudo -s mv ./k9s /usr/local/bin/k9s
rm k9s_linux_amd64.deb




########################
##### Configure OS #####
########################
# Increase inodes for asp.net applications
echo fs.inotify.max_user_instances=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

#############################
##### Provision Argo CD #####
#############################
