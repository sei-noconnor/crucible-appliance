#!/bin/bash 
images=$(echo "$ADMIN_PASS" | sudo -S -E bash -c "ctr images ls | awk 'NR>1 {print $1}' | awk -v RS= '{$1=$1}1')"
echo "$ADMIN_PASS" | sudo -S -E bash -c "k3s ctr export appliance-images.tar $images"