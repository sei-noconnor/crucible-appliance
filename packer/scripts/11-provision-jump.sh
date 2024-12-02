#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status
set -o pipefail # Consider failed pipelines as errors

echo "Provisioning script started."

# 1. Grow the partition and resize LVM
echo "Expanding partition and LVM..."
sudo growpart /dev/sda3
sudo pvresize /dev/sda3
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv

# 2. System update and desktop environment installation
echo "Updating and upgrading packages..."
sudo apt-get update && sudo apt-get upgrade -y
echo "Installing Cinnamon and Xubuntu desktop environments..."
sudo apt-get install -y xubuntu-desktop --no-install-recommends
sudo apt-get install -y chromium-browser

# 3. Install Visual Studio Code
echo "Installing Visual Studio Code..."
curl -LO https://vscode.download.prss.microsoft.com/dbazure/download/stable/f1a4fb101478ce6ec82fe9627c43efbf9e98c813/code_1.95.3-1731513102_amd64.deb
sudo apt install -y ./code_1.95.3-1731513102_amd64.deb

# 4. Install OpenLens
echo "Installing OpenLens..."
curl -LO https://github.com/MuhammedKalkan/OpenLens/releases/download/v6.5.2-366/OpenLens-6.5.2-366.amd64.deb
sudo apt install -y ./OpenLens-6.5.2-366.amd64.deb

# 5. Install Kubernetes CLI tools
echo "Installing Kubernetes CLI tools..."
curl -LO https://dl.k8s.io/release/v1.31.3/bin/linux/amd64/kubectl
sudo cp kubectl /usr/local/bin/kubectl
sudo chown root:root /usr/local/bin/kubectl
sudo chmod +x /usr/local/bin/kubectl

# 6. Install k9s
echo "Installing k9s..."
curl -LO https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_Linux_amd64.tar.gz
sudo tar -C /usr/local/bin -xvf k9s_Linux_amd64.tar.gz

# 7. Install open-vm-tools and XRDP for virtualization
echo "Installing virtualization tools..."
sudo apt-get install -y open-vm-tools xrdp

# 8. Install VSCode extensions
echo "Installing VSCode extensions..."
extensions=(
  "albert.tabout"
  "davidanson.vscode-markdownlint"
  "eamodio.gitlens"
  "esbenp.prettier-vscode"
  "formulahendry.code-runner"
  "github.codespaces"
  "github.remotehub"
  "github.vscode-github-actions"
  "golang.go"
  "hashicorp.hcl"
  "hashicorp.terraform"
  "ms-azuretools.vscode-docker"
  "ms-kubernetes-tools.vscode-kubernetes-tools"
  "ms-python.debugpy"
  "ms-python.python"
  "ms-python.vscode-pylance"
  "ms-vscode-remote.remote-containers"
  "ms-vscode-remote.remote-ssh"
  "ms-vscode-remote.remote-ssh-edit"
  "ms-vscode-remote.remote-wsl"
  "ms-vscode-remote.vscode-remote-extensionpack"
  "ms-vscode.azure-repos"
  "ms-vscode.cmake-tools"
  "ms-vscode.cpptools"
  "ms-vscode.cpptools-extension-pack"
  "ms-vscode.cpptools-themes"
  "ms-vscode.makefile-tools"
  "ms-vscode.powershell"
  "redhat.fabric8-analytics"
  "redhat.java"
  "redhat.vscode-yaml"
  "ritwickdey.liveserver"
  "shyykoserhiy.git-autoconfig"
  "streetsidesoftware.code-spell-checker"
  "tumido.crd-snippets"
  "twxs.cmake"
  "visualstudioexptteam.intellicode-api-usage-examples"
  "visualstudioexptteam.vscodeintellicode"
  "vscjava.vscode-gradle"
  "vscjava.vscode-java-debug"
  "vscjava.vscode-java-dependency"
  "vscjava.vscode-java-pack"
  "vscjava.vscode-java-test"
  "vscjava.vscode-maven"
  "vscode-ext.sync-rsync"
)
for ext in "${extensions[@]}"; do
  code --install-extension $ext || echo "Failed to install $ext"
done

echo "Provisioning script completed."
