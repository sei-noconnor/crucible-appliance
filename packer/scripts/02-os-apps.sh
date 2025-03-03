#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#

# Get vars from appliamce.yaml
source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
MIRRORS=$(cat <<EOF
mirrors:
  docker.io:
    endpoint:
      - https://mirror.gcr.io
  "*":
EOF
)

IS_ONLINE=$(curl -s --max-time 5 ifconfig.me >/dev/null && echo true || echo false)
echo "IS_ONLINE: $IS_ONLINE"

# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

################################
##### Install Apps         #####
################################
DIST_DIR=./dist
VAULT_VERSION="1.15.2"
ARGOCD_VERSION="2.13.1"

if $IS_ONLINE; then
    echo "Downloading Binaries"
    if [ ! -d $DIST_DIR/generic ]; then
        mkdir -p $DIST_DIR/{generic,containers,charts,deb}
    fi
    curl -C - -Lo $DIST_DIR/generic/k3s "https://github.com/k3s-io/k3s/releases/download/v1.31.3%2Bk3s1/k3s"
    curl -C - -Lo $DIST_DIR/generic/k3s-install.sh "https://get.k3s.io" && chmod +x "$DIST_DIR/generic/k3s-install.sh"
    curl -C - -Lo $DIST_DIR/generic/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    curl -C - -Lo $DIST_DIR/generic/kubectl "https://dl.k8s.io/release/v1.31.3/bin/linux/amd64/kubectl"
    curl -C - -Lo $DIST_DIR/generic/k9s_linux_amd64.tar.gz "https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_Linux_amd64.tar.gz"
    curl -C - -Lo $DIST_DIR/generic/argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/v$ARGOCD_VERSION/argocd-linux-amd64"
    curl -C - -Lo $DIST_DIR/generic/vault_${VAULT_VERSION}_linux_amd64.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"
    curl -C - -Lo $DIST_DIR/generic/go1.22.5.linux-amd64.tar.gz "https://dl.google.com/go/go1.22.5.linux-amd64.tar.gz"
    curl -C - -Lo $DIST_DIR/generic/helm-v3.16.3-linux-amd64.tar.gz https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
    curl -C - -Lo $DIST_DIR/generic/govc_Linux_x86_64.tar.gz https://github.com/vmware/govmomi/releases/download/v0.46.2/govc_Linux_x86_64.tar.gz
    curl -C - -Lo $DIST_DIR/generic/k3sup https://github.com/alexellis/k3sup/releases/download/0.13.6/k3sup
    curl -C - -Lo $DIST_DIR/generic/nerdctl-2.0.3-linux-amd64.tar.gz https://github.com/containerd/nerdctl/releases/download/v2.0.3/nerdctl-2.0.3-linux-amd64.tar.gz
    curl -C - -Lo $DIST_DIR/generic/hauler_1.2.0-dev.2_linux_amd64.tar.gz https://github.com/hauler-dev/hauler/releases/download/v1.2.0-dev.2/hauler_1.2.0-dev.2_linux_amd64.tar.gz
    curl -C - -Lo $DIST_DIR/generic/terraform_1.10.5_linux_amd64.zip https://releases.hashicorp.com/terraform/1.10.5/terraform_1.10.5_linux_amd64.zip
    curl -C - -Lo $DIST_DIR/generic/packer_1.12.0_linux_amd64.zip https://releases.hashicorp.com/packer/1.12.0/packer_1.12.0_linux_amd64.zip
    curl -C - -Lo $DIST_DIR/generic/podman-linux-amd64.tar.gz https://github.com/containers/podman/releases/download/v5.4.0/podman-remote-static-linux_amd64.tar.gz
    curl -C - -Lo $DIST_DIR/generic/kind-linux-amd64 https://github.com/kubernetes-sigs/kind/releases/download/v0.26.0/kind-linux-amd64
    curl -C - -Lo $DIST_DIR/generic/lazygit_0.48.0_linux_x86_64.tar.gz https://github.com/jesseduffield/lazygit/releases/download/v0.48.0/lazygit_0.48.0_Linux_x86_64.tar.gz
    curl -C - -Lo $DIST_DIR/generic/kubectl-node-shell https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell
fi  
# Install yq
sudo mv $DIST_DIR/generic/yq /usr/bin/yq && sudo chmod +x /usr/bin/yq

# Install K3s
sudo mkdir -p /etc/rancher/k3s
mkdir -p ~/.kube
sudo echo "$MIRRORS" > /etc/rancher/k3s/registries.yaml
sudo cp $DIST_DIR/generic/k3s /usr/local/bin/k3s && sudo chmod +x /usr/local/bin/k3s
INSTALL_K3S_VERSION="v1.31.3+k3s1" K3S_KUBECONFIG_MODE="644" INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC="server --disable traefik --embedded-registry --etcd-expose-metrics  --prefer-bundled-bin --node-name crucible-ctrl-01 --tls-san ${DOMAIN:-crucible.io} --cluster-init" $DIST_DIR/generic/k3s-install.sh
mkdir ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i "s/default/crucible-appliance/g" ~/.kube/config
sed -i "s/127.0.0.1/${DOMAIN}/g" ~/.kube/config
sudo chown -R $SSH_USERNAME:$SSH_USERNAME ~/.kube
chmod go-r ~/.kube/config

# Install Kubectl
install -o root -g root -m 0755 $DIST_DIR/generic/kubectl /usr/local/bin/kubectl
# Install kubectl node-shell
chmod +x $DIST_DIR/generic/kubectl-node-shell
sudo mv $DIST_DIR/generic/kubectl-node-shell /usr/local/bin/kubectl-node_shell

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
sudo chown root:root /usr/local/bin/vault
sudo chmod +x /usr/local/bin/vault
vault version

# Install Nerdctl
sudo tar -C /usr/local/bin -xzf $DIST_DIR/generic/nerdctl-2.0.3-linux-amd64.tar.gz
sudo chown root:root /usr/local/bin/nerdctl
sudo chmod +x /usr/local/bin/nerdctl

# Install Podman
sudo tar -C /usr/local/bin -xzf $DIST_DIR/generic/podman-linux-amd64.tar.gz
sudo chown root:root /usr/local/bin/podman
sudo chmod +x /usr/local/bin/podman
podman version

# Install Hauler
sudo tar -C /usr/local/bin -xzf $DIST_DIR/generic/hauler_1.2.0-dev.2_linux_amd64.tar.gz
sudo chown root:root /usr/local/bin/hauler
sudo chmod +x /usr/local/bin/hauler

# Install Terraform
sudo unzip -d /usr/local/bin $DIST_DIR/generic/terraform_1.10.5_linux_amd64.zip
sudo chown root:root /usr/local/bin/terraform
sudo chmod +x /usr/local/bin/terraform
terraform version

# Install Packer
sudo unzip -d /usr/local/bin $DIST_DIR/generic/packer_1.12.0_linux_amd64.zip
sudo chown root:root /usr/local/bin/packer
sudo chmod +x /usr/local/bin/packer
packer version

# Install Kind
sudo cp $DIST_DIR/generic/kind-linux-amd64 /usr/local/bin/kind
sudo chown root:root /usr/local/bin/kind
sudo chmod +x /usr/local/bin/kind
kind version

# Install lazygit
sudo tar -C /usr/local/bin -xzf $DIST_DIR/generic/lazygit_0.48.0_linux_x86_64.tar.gz
# Install Brew
# NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> /home/ubuntu/.baschrc
# eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# brew install gcc

# Reset Permissions
sudo chown -R $SSH_USERNAME:$SSH_USERNAME /home/$SSH_USERNAME