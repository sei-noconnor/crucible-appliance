#!/bin/bash -x

# Ensure yq is installed
if ! command -v yq &> /dev/null
then
    echo "yq could not be found, please install it to proceed."
    exit
fi

if [ -f ./appliance.yaml ]; then
    export $(yq '.vars | to_entries | .[] | "\(.key | upcase)=\(.value)"' ./appliance.yaml | xargs)
fi
MIRRORS=$(cat <<EOF
mirrors:
  docker.io:
    endpoint:
      - https://mirror.gcr.io
  "*":
EOF
)
sudo echo "$MIRRORS" > registries.yaml
export GOVC_URL="https://${VSPHERE_USER}:${VSPHERE_PASSWORD}@${VSPHERE_SERVER}"
export GOVC_INSECURE=1
export NODES=$(yq '.cluster | to_entries | .[] | .key' ./appliance.yaml | xargs)
echo "$SUDO_PASSWORD" | sudo -E -S cp /var/lib/rancher/k3s/server/node-token ./dist/ssl/server/tls/node-token
echo "$SUDO_PASSWORD" | sudo -E -S chown $SUDO_USERNAME:$SUDO_USERNAME ./dist/ssl/server/tls/node-token


cat <<EOF > cmds.sh
#!/bin/bash 
echo "$SUDO_PASSWORD" | sudo -S echo "$SUDO_USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$SUDO_USERNAME
echo "$SUDO_PASSWORD" | sudo -S chmod 0440 /etc/sudoers.d/$SUDO_USERNAME
sleep 2
sudo cp /home/$SUDO_USERNAME/k3s /usr/local/bin/k3s
sudo chmod +x /usr/local/bin/k3s
sudo mkdir -p /etc/rancher/k3s 
mkdir -p ~/.kube 
sudo cp ~/registries.yaml /etc/rancher/k3s/registries.yaml
chmod +x /home/$SUDO_USERNAME/k3s-install.sh
INSTALL_K3S_VERSION="v1.31.3+k3s1" K3S_KUBECONFIG_MODE="644" INSTALL_K3S_SKIP_DOWNLOAD=true \
INSTALL_K3S_EXEC="server --server https://$DOMAIN:6443 --disable traefik --embedded-registry --etcd-expose-metrics  --prefer-bundled-bin --tls-san ${DOMAIN:-crucible.io} --token-file /home/$SUDO_USERNAME/node-token" /home/$SUDO_USERNAME/k3s-install.sh
mkdir ~/.kube 
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config 
sed -i "s/default/crucible-appliance/g" ~/.kube/config
sed -i "s/127.0.0.1/${DOMAIN}/g" ~/.kube/config
sudo chown -R $SUDO_USERNAME:$SUDO_USERNAME ~/.kube
chmod go-r ~/.kube/config 
EOF


# govc guest.upload -vm crucible-ctrl-02 -l $SUDO_USERNAME:$SUDO_PASSWORD ./dist/generic/k3s-install.sh /home/$SUDO_USERNAME/k3s-install.sh
# govc guest.upload -vm crucible-ctrl-02 -l $SUDO_USERNAME:$SUDO_PASSWORD ./dist/generic/k3s /home/$SUDO_USERNAME/k3s
# govc guest.upload -vm crucible-ctrl-02 -l $SUDO_USERNAME:$SUDO_PASSWORD -f ./dist/ssl/server/tls/node-token /home/$SUDO_USERNAME/node-token
# govc guest.upload -vm crucible-ctrl-02 -l $SUDO_USERNAME:$SUDO_PASSWORD -f ./cmds.sh /home/$SUDO_USERNAME/cmds.sh
# govc guest.upload -vm crucible-ctrl-02 -l $SUDO_USERNAME:$SUDO_PASSWORD -f ./registries.yaml /home/$SUDO_USERNAME/registries.yaml
# govc guest.run -vm crucible-ctrl-02 -l $SUDO_USERNAME:$SUDO_PASSWORD -e SUDO_USERNAME=$SUDO_USERNAME -e SUDO_PASSWORD=$SUDO_PASSWORD chmod +x /home/$SUDO_USERNAME/cmds.sh
# govc guest.run -vm crucible-ctrl-02 -l $SUDO_USERNAME:$SUDO_PASSWORD -e SUDO_USERNAME=$SUDO_USERNAME -e SUDO_PASSWORD=$SUDO_PASSWORD /home/$SUDO_USERNAME/cmds.sh




# transfer files to the nodes
for node in $NODES; do
  # Attach a disk to the node
  govc guest.upload -vm $node -l $SUDO_USERNAME:$SUDO_PASSWORD ./packer/scripts/01-add-volume.sh /home/$SUDO_USERNAME/01-add-volume.sh
  govc guest.upload -vm $node -l $SUDO_USERNAME:$SUDO_PASSWORD ./dist/generic/k3s-install.sh /home/$SUDO_USERNAME/k3s-install.sh
  govc guest.upload -vm $node -l $SUDO_USERNAME:$SUDO_PASSWORD ./dist/generic/k3s /home/$SUDO_USERNAME/k3s
  govc guest.upload -vm $node -l $SUDO_USERNAME:$SUDO_PASSWORD -f ./dist/ssl/server/tls/node-token /home/$SUDO_USERNAME/node-token
  govc guest.upload -vm $node -l $SUDO_USERNAME:$SUDO_PASSWORD -f ./cmds.sh /home/$SUDO_USERNAME/cmds.sh
  govc guest.upload -vm $node -l $SUDO_USERNAME:$SUDO_PASSWORD -f ./registries.yaml /home/$SUDO_USERNAME/registries.yaml
  # govc guest.run -vm $node -l $SUDO_USERNAME:$SUDO_PASSWORD -e SUDO_USERNAME=$SUDO_USERNAME -e SUDO_PASSWORD=$SUDO_PASSWORD chmod +x /home/$SUDO_USERNAME/cmds.sh
  # govc guest.run -vm $node -l $SUDO_USERNAME:$SUDO_PASSWORD -e SUDO_USERNAME=$SUDO_USERNAME -e SUDO_PASSWORD=$SUDO_PASSWORD /home/$SUDO_USERNAME/cmds.sh
done





