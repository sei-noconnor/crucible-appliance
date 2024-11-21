#!/bin/bash
# Create systemd service to configure netplan primary interface
echo "Current Directory is: ${PWD}"
cp ./packer/scripts/configure_nic /usr/local/bin/configure_nic
cat <<EOF > /etc/systemd/system/configure-nic.service
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
sudo chmod +x /usr/local/bin/configure_nic
sudo systemctl daemon-reload
sudo systemctl enable configure-nic