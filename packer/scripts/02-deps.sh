#!/bin/bash -x
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#
# Crucible Appliance 02-deps.sh

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
CRUCIBLE_VARS=$(cat <<EOF
#!/bin/bash 
export APPLIANCE_VERSION=
export APPLIANCE_IP=
APPLIANCE_ENVIRONMENT=
EOF
)

# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

# Get the appliance version
if git rev-parse --git-dir > /dev/null 2>&1; then
    VERSION_TAG=$(git tag --points-at HEAD)
    GIT_BRANCH=$(git branch --show-current)
    GIT_HASH=$(git rev-parse --short HEAD)
fi

if [ -n "$VERSION_TAG" ]; then
    BUILD_VERSION=$VERSION_TAG
elif [ -n "$GITHUB_PULL_REQUEST" ]; then
    BUILD_VERSION=PR$GITHUB_PULL_REQUEST-$GIT_HASH
elif [ -n "$GIT_HASH" ]; then
    BUILD_VERSION=${GIT_BRANCH:0:15}-$GIT_HASH
else
    BUILD_VERSION="custom-$(date '+%Y%m%d')"
fi

if [ -z $APPLIANCE_VERSION ]; then 
    APPLIANCE_VERSION="crucible-appliance-$BUILD_VERSION"
    echo "Setting APPLIANCE_VERSION to $APPLIANCE_VERSION in /etc/appliance_version"
    if [[ ! -f /etc/profile.d/crucible-env.sh ]]; then 
        sudo echo "$CRUCIBLE_VARS" > /etc/profile.d/crucible-env.sh
    fi
    sudo chmod a+rx /etc/profile.d/crucible-env.sh
    tmp_file=/tmp/temp-$(openssl rand -hex 4).txt
    sudo echo "$APPLIANCE_VERSION" > /etc/appliance_version
    echo "Setting APPLIANCE_VERSION to $APPLIANCE_VERSION in /etc/profile.d/crucible-env.sh"
    sudo awk "/APPLIANCE_VERSION=/ {print \"export APPLIANCE_VERSION=$APPLIANCE_VERSION\"; next} 1" /etc/profile.d/crucible-env.sh > $tmp_file && sudo mv -f $tmp_file /etc/profile.d/crucible-env.sh
else
    if [ $APPLIANCE_VERSION != crucible-appliance-$BUILD_VERSION ]; then 
        sudo echo "$APPLIANCE_VERSION" > /etc/appliance_version
    fi
fi

tmp_file=/tmp/temp-$(openssl rand -hex 4).txt
sudo awk "/APPLIANCE_IP=/ {print \"export APPLIANCE_IP=$APPLIANCE_IP\"; next} 1" /etc/profile.d/crucible-env.sh > $tmp_file && sudo mv -f $tmp_file /etc/profile.d/crucible-env.sh
sudo awk "/APPLIANCE_ENVIRONMENT=/ {print \"export APPLIANCE_ENVIRONMENT=APPLIANCE\"; next} 1" /etc/profile.d/crucible-env.sh > $tmp_file && sudo mv -f $tmp_file /etc/profile.d/crucible-env.sh


######################
###### Update OS #####
######################
sudo apt-get update -y && sudo NONINTERACTIVE=1 apt-get dist-upgrade --yes && sudo apt-get autoremove -y
sudo apt-get install -y build-essential avahi-daemon jq nfs-common sshpass postgresql-client make logrotate git unzip

########################
##### Configure OS #####
########################
# Set hostname 
hostname -b crucible
# Set Timezone EST
sudo timedatectl set-timezone EST
# Increase inodes for asp.net applications
echo fs.inotify.max_user_instances=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
sudo chown -R $SSH_USERNAME:$SSH_USERNAME ~

# Stop multipathd errors in syslog
sudo sed -i '/^blacklist {/,/^}$/d' /etc/multipath.conf
cat <<EOF >> /etc/multipath.conf
blacklist {
    devnode "^sd[a-z0-9]+"
}
blacklist {
    device {
        vendor "IET"
        product "VIRTUAL-DISK"
    }
}
EOF
sudo systemctl restart multipathd

# Restart mDNS daemon to avoid conflict with other hosts
sudo systemctl restart avahi-daemon

# Customize MOTD and other text for the appliance
chmod -x /etc/update-motd.d/00-header
chmod -x /etc/update-motd.d/10-help-text
sed -i -r 's/(ENABLED=)1/\0/' /etc/default/motd-news
echo "Current Directory is: $PWD"
cp packer/scripts/display-banner /etc/update-motd.d/05-display-banner

# Will need later when we install mkdocs #remove
# sed -i "s/{version}/$APPLIANCE_VERSION/" ~/mkdocs/docs/index.md
echo -e "Crucible Appliance $APPLIANCE_VERSION" > /etc/issue

# setup startup script
echo "Setting Up crucible-appliance startup script $PWD"
yes | cp -rf $PWD/packer/scripts/crucible-appliance-startup.service /etc/systemd/system
yes | cp -rf $PWD/packer/scripts/crucible-appliance-startup.sh /usr/local/bin/
chmod 744 /usr/local/bin/crucible-appliance-startup.sh
chmod 664 /etc/systemd/system/crucible-appliance-startup.service
sudo systemctl daemon-reload
sudo systemctl enable crucible-appliance-startup.service

# Create systemd service to configure netplan primary interface

# cp packer/scripts/configure_nic /usr/local/bin
# cat <<EOF > /etc/systemd/system/configure_nic.service
# [Unit]
# Description=Configure Netplan primary Ethernet interface
# After=network.target
# Before=k3s.service

# [Service]
# Type=oneshot
# ExecStart=/usr/local/bin/configure_nic

# [Install]
# WantedBy=multi-user.target
# EOF
# chmod +x /usr/local/bin/configure_nic
# # Remove configure_nic Flag
# if [ -f /etc/.configure-nic ]; then 
#   rm /etc/.configure-nic
# fi
# systemctl daemon-reload
# systemctl enable configure_nic

CURRENT_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
APPLIANCE_VERSION=${APPLIANCE_VERSION:-$(cat /etc/appliance_version)}
DOMAIN=${DOMAIN:-crucible.local}

if [[ $APPLIANCE_IP != $CURRENT_IP ]]; then
    # Delete old entry
    sudo sed -i "/$DOMAIN/d" /etc/hosts
    msg="Entry being added in hosts file. entry: '$CURRENT_IP    $DOMAIN'"
    # Append it to the hosts file
    tmp_file=/tmp/temp-$(openssl rand -hex 4).txt
    sudo echo "$CURRENT_IP   $DOMAIN" >> /etc/hosts
    msg="Entry update in host file: /etc/hosts '$CURRENT_IP   $DOMAIN'"
fi

################################
##### Install Dependencies #####
################################

# Install yq
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

# Install K3s
sudo mkdir -p /etc/rancher/k3s
mkdir -p ~/.kube
# sudo echo "nameserver 10.0.1.1" >> /etc/rancher/k3s/resolv.conf
sudo echo "$MIRRORS" > /etc/rancher/k3s/registries.yaml
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.29.1+k3s1" K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="server --disable traefik --embedded-registry --etcd-expose-metrics --cluster-init --prefer-bundled-bin --tls-san ${DOMAIN:-crucible.local}" sh -
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
sudo NEEDRESTART_MODE=a apt-get install --yes ./k9s_linux_amd64.deb
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

# Install Vault
VERSION="1.15.2"
mkdir -p dist/tools
curl https://releases.hashicorp.com/vault/${VERSION}/vault_${VERSION}_linux_amd64.zip -o dist/tools/vault_${VERSION}_linux_amd64.zip
unzip dist/tools/vault_${VERSION}_linux_amd64.zip -d /usr/local/bin/
vault --version

# Install Brew
# NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> /home/ubuntu/.baschrc
# eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# brew install gcc

# Take base cluster snapshot
echo "Sleeping for 20 seconds for snapshot"
sleep 20
k3s etcd-snapshot save --name base-cluster

# Delete Ubuntu machine ID for proper DHCP operation on deploy
#echo -n > /etc/machine-id