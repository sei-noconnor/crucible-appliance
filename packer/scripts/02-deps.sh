#!/bin/bash -x
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#
# Crucible Appliance 02-deps.sh

echo "$APPLIANCE_VERSION" > /etc/appliance_version

# Disable swap for Kubernetes
swapoff -a
sed -i -r 's/(\/swap\.img.*)/#\1/' /etc/fstab
rm -rf /swap.img

###############
#### VARS #####
###############
APPLIANCE_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
MIRRORS=$(cat <<EOF
mirrors:
  "*":
EOF
)

######################
###### Update OS #####
######################
sudo apt update -y && sudo NONINTERACTIVE=1 apt-get dist-upgrade --yes && sudo apt autoremove -y
sudo apt install -y build-essential dnsmasq avahi-daemon jq nfs-common sshpass postgresql-client make logrotate git

########################
##### Configure OS #####
########################
# Increase inodes for asp.net applications
echo fs.inotify.max_user_instances=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
sudo chown -R $SSH_USERNAME:$SSH_USERNAME ~

# Stop multipathd errors in syslog
cat <<EOF >> /etc/multipath.conf
blacklist {
    devnode "sda$"
}
EOF
systemctl restart multipathd

# Add dnsmasq resolver and other required packages
PRIMARY_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
mkdir /etc/dnsmasq.d
cat <<EOF > /etc/dnsmasq.d/crucible.conf
bind-interfaces
listen-address=10.0.1.1
interface-name=crucible.local,$PRIMARY_INTERFACE
EOF

cat <<EOF > /etc/netplan/01-loopback.yaml
# Add loopback address for pods to use dnsmasq as upstream resolver
network:
  version: 2
  ethernets:
    lo:
      match:
        name: lo
      addresses:
        - 127.0.0.1/8:
            label: lo
        - 10.0.1.1/32:
            label: lo:host-access
        - ::1/128
EOF
chmod -R 600 /etc/netplan/
netplan apply

# Restart mDNS daemon to avoid conflict with other hosts
systemctl restart avahi-daemon

# Customize MOTD and other text for the appliance
chmod -x /etc/update-motd.d/00-header
chmod -x /etc/update-motd.d/10-help-text
sed -i -r 's/(ENABLED=)1/\0/' /etc/default/motd-news
echo "Current Directory is: $PWD"
cp packer/scripts/display-banner /etc/update-motd.d/05-display-banner
# Will need later when we install mkdocs #remove
# sed -i "s/{version}/$APPLIANCE_VERSION/" ~/mkdocs/docs/index.md
echo -e "Crucible Appliance $APPLIANCE_VERSION \\\n \l \n" >> /etc/issue

# Create systemd service to configure netplan primary interface

cp packer/scripts/configure_nic /usr/local/bin
cat <<EOF > /etc/systemd/system/configure_nic.service
[Unit]
Description=Configure Netplan primary Ethernet interface
After=network.target
Before=k3s.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/configure_nic

[Install]
WantedBy=multi-user.target
EOF
chmod +x /usr/local/bin/configure_nic
# Remove configure_nic Flag
if [ -f /etc/.configure-nic ]; then 
  rm /etc/.configure-nic
fi
systemctl daemon-reload
systemctl enable configure_nic

APPLIANCE_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
# Add hosts Entry 
if ! grep -q "^$APPLIANCE_IP\s\+crucible.local\$" /etc/hosts; then
    # If it doesn't exist, append it to the hosts file
    echo "$APPLIANCE_IP crucible.local" >> /etc/hosts
    echo "Entry added to hosts file."
else
    echo "Entry already exists in hosts file."
fi

# Set hostname 
hostname -b crucible.local

################################
##### Install Dependencies #####
################################

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
sed -i "s/127.0.0.1/crucible.local/g" ~/.kube/config
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
# NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> /home/ubuntu/.baschrc
# eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# brew install gcc

# Take base cluster snapshot
echo "Sleeping for 20 seconds for snapshot"
sleep 20
k3s etcd-snapshot save --name base-cluster

# # Delete Ubuntu machine ID for proper DHCP operation on deploy
# # echo -n > /etc/machine-id