#!/bin/bash

# Ensure yq is installed
if ! command -v yq &> /dev/null
then
    echo "yq could not be found, please install it to proceed."
    exit
fi

# Generate Ansible inventory
yq -o j '.cluster' /home/crucible/crucible-appliance/appliance.yaml | jq -r '
  to_entries | 
  .[] | 
  "\(.key) ansible_host=\(.value.ip) ansible_user=\(.value.vars.sudo_username) ansible_ssh_pass=\(.value.vars.sudo_password)"
' > /home/crucible/crucible-appliance/ansible_inventory.ini

# Add control and worker groups
echo "[control]" >> /home/crucible/crucible-appliance/ansible_inventory.ini
yq -o j '.cluster' /home/crucible/crucible-appliance/appliance.yaml | jq -r '
  to_entries | 
  .[] | 
  select(.key | contains("ctrl")) | 
  .key
' >> /home/crucible/crucible-appliance/ansible_inventory.ini

echo "[worker]" >> /home/crucible/crucible-appliance/ansible_inventory.ini
yq -o j '.cluster' /home/crucible/crucible-appliance/appliance.yaml | jq -r '
  to_entries | 
  .[] | 
  select(.key | contains("wrkr")) | 
  .key
' >> /home/crucible/crucible-appliance/ansible_inventory.ini
