#!/bin/bash -x
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 
    exit 1
fi
rm -rf /usr/local/share/ca-certificates/*.crt
sudo dpkg-reconfigure -p critical ca-certificates
update-ca-certificates