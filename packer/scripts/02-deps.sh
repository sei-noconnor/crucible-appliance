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
MIRRORS=$(cat <<EOF
mirrors:
  "*":
EOF
)

######################
###### Update OS #####
######################
sudo apt update -y && sudo NEEDRESTART_MODE=a apt-get dist-upgrade build-essentials --yes && sudo apt autoremove -y

################################
##### Install Dependencies #####
################################
# Install Apt Packages
sudo apt install -y jq nfs-common postgresql-client make

# Install yq
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

# Install K3s
sudo mkdir -p /etc/rancher/k3s
mkdir -p ~/.kube
sudo echo "nameserver 10.0.1.1" >> /etc/rancher/k3s/resolv.conf
sudo echo "$MIRRORS" > /etc/rancher/k3s/registries.yaml
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.29.1+k3s1" K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="server --disable traefik --embedded-registry --etcd-expose-metrics --cluster-init --prefer-bundled-bin" sh -
mkdir ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's/default/crucible-appliance/g' ~/.kube/config
sed -i "s/127.0.0.1/$APPLIANCE_IP/g" ~/.kube/config
sudo chown -R $SSH_USERNAME:$SSH_USERNAME ~/.kube
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

# Install CFSSL for certificate generation
curl -sLo /usr/local/bin/cfssl https://github.com/cloudflare/cfssl/releases/download/v1.6.3/cfssl_1.6.3_linux_amd64
curl -sLo /usr/local/bin/cfssljson https://github.com/cloudflare/cfssl/releases/download/v1.6.3/cfssljson_1.6.3_linux_amd64
chmod +x /usr/local/bin/cfssl*

# Install argocd-cli
VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION) 
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64 
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd 
rm argocd-linux-amd64

# Install go
mkdir -p dist/tools
curl https://dl.google.com/go/go1.22.5.linux-amd64.tar.gz -o dist/tools/go1.22.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf ./dist/tools/go1.22.5.linux-amd64.tar.gz

# Install Brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> /home/ubuntu/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew install gcc


########################
##### Configure OS #####
########################
# Increase inodes for asp.net applications
echo fs.inotify.max_user_instances=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
