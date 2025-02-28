#!/bin/bash -x
HOSTS_FILE=/etc/hosts
DOMAIN=${1:-crucible.io}
IP=$(ip route get 1 | awk '{print $(NF-2);exit}')


if [ -z "$IP" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

# Delete old entry
sudo sed -i "/$DOMAIN/d" $HOSTS_FILE
msg="Entry being added in hosts file. entry: '$IP    $DOMAIN cd.$DOMAIN help.$DOMAIN keystore.$DOMAIN id.$DOMAIN code.$DOMAIN'"
# Append it to the hosts file
sudo echo "$IP  $DOMAIN cd.$DOMAIN help.$DOMAIN keystore.$DOMAIN id.$DOMAIN code.$DOMAIN" >> $HOSTS_FILE
msg="Entry update in host file: $HOSTS_FILE '$IP   $DOMAIN cd.$DOMAIN help.$DOMAIN keystore.$DOMAIN id.$DOMAIN code.$DOMAIN'"

