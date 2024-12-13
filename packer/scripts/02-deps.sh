#!/bin/bash
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
export APPLIANCE_ENVIRONMENT=
export IS_ONLINE=
EOF
)
IS_ONLINE=$(curl -s --max-time 5 ifconfig.me >/dev/null && echo true || echo false)
echo "IS_ONLINE: $IS_ONLINE"
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
    sudo echo "$APPLIANCE_VERSION" > /etc/appliance_version
else
    if [ $APPLIANCE_VERSION != crucible-appliance-$BUILD_VERSION ]; then 
        sudo echo "$APPLIANCE_VERSION" > /etc/appliance_version
        sudo sed -i "s/APPLIANCE_VERSION=/export APPLIANCE_VERSION=$APPLIANCE_VERSION/d" /etc/profile.d/crucible-env.sh
    fi
fi

# Set Up crucible-vars.sh
if [[ ! -f /etc/profile.d/crucible-env.sh ]]; then 
    sudo echo "$CRUCIBLE_VARS" > /etc/profile.d/crucible-env.sh
    sudo chmod a+rx /etc/profile.d/crucible-env.sh
    echo "Setting APPLIANCE_VERSION to $APPLIANCE_VERSION in /etc/profile.d/crucible-env.sh"
    sudo sed -i "/APPLIANCE_VERSION=/c\export APPLIANCE_VERSION=\\$APPLIANCE_VERSION" /etc/profile.d/crucible-env.sh
    sudo sed -i "/APPLIANCE_IP=/c\export APPLIANCE_IP=\\$APPLIANCE_IP" /etc/profile.d/crucible-env.sh
    sudo sed -i "/APPLIANCE_ENVIRONMENT=APPLIANCE/c\export APPLIANCE_ENVIRONMENT=APPLIANCE" /etc/profile.d/crucible-env.sh
    sudo sed -i "/IS_ONLINE=/c\export IS_ONLINE=\\$IS_ONLINE" /etc/profile.d/crucible-env.sh
else
    echo "Setting APPLIANCE_VERSION to $APPLIANCE_VERSION in /etc/profile.d/crucible-env.sh"
    sudo sed -i "/APPLIANCE_VERSION=/c\export APPLIANCE_VERSION=\\$APPLIANCE_VERSION" /etc/profile.d/crucible-env.sh
    sudo sed -i "/APPLIANCE_IP=/c\export APPLIANCE_IP=\\$APPLIANCE_IP" /etc/profile.d/crucible-env.sh
    sudo sed -i "/APPLIANCE_ENVIRONMENT=/c\export APPLIANCE_ENVIRONMENT=APPLIANCE" /etc/profile.d/crucible-env.sh
    sudo sed -i "/IS_ONLINE=/c\export IS_ONLINE=\\$IS_ONLINE" /etc/profile.d/crucible-env.sh
fi

######################
###### Update OS #####
######################
if $IS_ONLINE; then
    sudo apt-get update -y && sudo NONINTERACTIVE=1 apt-get dist-upgrade --yes && sudo apt-get autoremove -y
    sudo NONINTERACTIVE=1 apt-get install -y build-essential jq nfs-common sshpass postgresql-client make logrotate git unzip apache2-utils
fi
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
# sudo systemctl restart avahi-daemon

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
DOMAIN=${DOMAIN:-crucible.io}


# Delete old entry
sudo sed -i "/$DOMAIN/d" /etc/hosts
msg="Entry being added in hosts file. entry: '$CURRENT_IP    $DOMAIN'"
# Append it to the hosts file
tmp_file=/tmp/temp-$(openssl rand -hex 4).txt
sudo echo "$CURRENT_IP   $DOMAIN" >> /etc/hosts
msg="Entry update in host file: /etc/hosts '$CURRENT_IP   $DOMAIN'"


################################
##### Install Dependencies #####
################################
DIST_DIR=/home/crucible/crucible-appliance/dist
VAULT_VERSION="1.15.2"
ARGOCD_VERSION="2.13.1"

if [ $IS_ONLINE ]; then
    echo "Downloading Binaries"
    if [ ! -d $DIST_DIR/generic ]; then
        mkdir -p $DIST_DIR/{generic,containers,charts,deb}
    fi
    curl -Lo $DIST_DIR/generic/k3s "https://github.com/k3s-io/k3s/releases/download/v1.31.3%2Bk3s1/k3s"
    curl -Lo $DIST_DIR/generic/k3s-install.sh "https://get.k3s.io" && chmod +x "$DIST_DIR/generic/k3s-install.sh"
    curl -Lo $DIST_DIR/generic/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    curl -Lo $DIST_DIR/generic/kubectl "https://dl.k8s.io/release/v1.31.3/bin/linux/amd64/kubectl"
    curl -Lo $DIST_DIR/generic/k9s_linux_amd64.tar.gz "https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_Linux_amd64.tar.gz"
    curl -Lo $DIST_DIR/generic/argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/v$ARGOCD_VERSION/argocd-linux-amd64"
    curl -Lo $DIST_DIR/generic/vault_${VAULT_VERSION}_linux_amd64.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"
    curl -Lo $DIST_DIR/generic/go1.22.5.linux-amd64.tar.gz "https://dl.google.com/go/go1.22.5.linux-amd64.tar.gz"
    curl -Lo $DIST_DIR/generic/helm-v3.16.3-linux-amd64.tar.gz https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
    curl -Lo $DIST_DIR/generic/govc_Linux_x86_64.tar.gz https://github.com/vmware/govmomi/releases/download/v0.46.2/govc_Linux_x86_64.tar.gz
    curl -Lo $DIST_DIR/generic/k3sup https://github.com/alexellis/k3sup/releases/download/0.13.6/k3sup
fi  
# Install yq
sudo mv $DIST_DIR/generic/yq /usr/bin/yq && sudo chmod +x /usr/bin/yq

# Install K3s
sudo mkdir -p /etc/rancher/k3s
mkdir -p ~/.kube
sudo echo "$MIRRORS" > /etc/rancher/k3s/registries.yaml
sudo mv $DIST_DIR/generic/k3s /usr/local/bin/k3s && sudo chmod +x /usr/local/bin/k3s
INSTALL_K3S_VERSION="v1.31.3+k3s1" K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="server --disable traefik --embedded-registry --etcd-expose-metrics --cluster-init --prefer-bundled-bin --tls-san ${DOMAIN:-crucible.io}" $DIST_DIR/generic/k3s-install.sh
mkdir ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i "s/default/crucible-appliance/g" ~/.kube/config
sed -i "s/127.0.0.1/${DOMAIN}/g" ~/.kube/config
sudo chown -R $SSH_USERNAME:$SSH_USERNAME ~/.kube
chmod go-r ~/.kube/config

# Install Kubectl
install -o root -g root -m 0755 $DIST_DIR/generic/kubectl /usr/local/bin/kubectl

# Install Helm
tar -C /usr/local/bin -xzf "$DIST_DIR/generic/helm-v3.16.3-linux-amd64.tar.gz" linux-amd64/helm --strip-components=1 
sudo chown root:root /usr/local/bin/helm

# Install K9s
sudo tar -C /usr/local/bin -xzf $DIST_DIR/generic/k9s_linux_amd64.tar.gz 

# Install argocd-cli
sudo install -m 555 $DIST_DIR/generic/argocd-linux-amd64 /usr/local/bin/argocd 

# Install go
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf $DIST_DIR/generic/go1.22.5.linux-amd64.tar.gz

# Install govc
sudo tar -C /usr/local/bin -xzf $DIST_DIR/generic/govc_Linux_x86_64.tar.gz
sudo chown root:root /usr/local/bin/govc
sudo chmod +x /usr/local/bin/govc

# Install k3sup
sudo cp $DIST_DIR/generic/govc_Linux_x86_64.tar.gz /usr/local/bin/k3sup
sudo chown root:root /usr/local/bin/k3sup
sudo chmod +x /usr/local/bin/k3sup

# Install Vault
unzip $DIST_DIR/generic/vault_${VAULT_VERSION}_linux_amd64.zip -d /usr/local/bin/
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
sudo chown -R $SSH_USERNAME:$SSH_USERNAME /home/$SSH_USERNAME

# limit docker pulls if container images exist
if [ -f $DIST_DIR/containers/images-amd64.tar.zst ]; then 
    make gitea-import-images
fi

# Delete Ubuntu machine ID for proper DHCP operation on deploy
#echo -n > /etc/machine-id