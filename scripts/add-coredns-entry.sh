#!/bin/bash

# Set the namespace and configmap name for CoreDNS
NAMESPACE="kube-system"
CONFIGMAP_NAME="coredns-custom"
DOMAIN=${2:-crucible.io}
IP=$(ip route get 1 | awk '{print $(NF-2);exit}')


if [ -z "$IP" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <ip> <domain>"
  exit 1
fi
# Backup the current configmap to a file
BACKUP_FILE="$CONFIGMAP_NAME-backup-$(date +%Y%m%d%H%M%S).yaml"
cat >$BACKUP_FILE <<EOF
apiVersion: v1
data:
  crucible.server: |
    $DOMAIN:53 {
      log
      errors
      hosts {
        $IP $DOMAIN
        $IP keystore.$DOMAIN
        $IP code.$DOMAIN
        $IP help.$DOMAIN
        $IP id.$DOMAIN
      }
    }
kind: ConfigMap
metadata:
  name: $CONFIGMAP_NAME
EOF

# Apply the modified configmap
k3s kubectl apply -n $NAMESPACE -f "$BACKUP_FILE"

# Restart CoreDNS pods to apply the new config
k3s kubectl rollout restart deployment coredns -n $NAMESPACE

echo "CoreDNS NodeHosts updated and pods restarted successfully."

rm $BACKUP_FILE
