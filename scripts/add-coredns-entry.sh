#!/bin/bash

# Set the namespace and configmap name for CoreDNS
NAMESPACE="kube-system"
CONFIGMAP_NAME="coredns"
IP=$1
DOMAIN=$2

if [ -z "$IP" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <ip> <domain>"
  exit 1
fi

# Backup the current configmap to a file
BACKUP_FILE="coredns-backup-$(date +%Y%m%d%H%M%S).yaml"
kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE -o yaml > $BACKUP_FILE
echo "Backup saved as $BACKUP_FILE"

# Extract NodeHosts from the backup file
NODEHOSTS=$(yq e '.data.NodeHosts' "$BACKUP_FILE")

# Define the new hosts entry
NEW_ENTRY="$IP $DOMAIN"

# Modify the NodeHosts entry in the backup file
UPDATED_NODEHOSTS=$(echo "$NODEHOSTS" | awk -v domain="$DOMAIN" -v new_entry="$NEW_ENTRY" '
{
  if ($2 == domain) {
    print new_entry;  # Replace the existing entry for the domain
    found = 1;
  } else {
    print;
  }
}
END {
  if (!found) {
    print new_entry;  # Add the new entry if the domain was not found
  }
}')

# Update the backup file with the modified NodeHosts content
yq e ".data.NodeHosts = \"$(echo "$UPDATED_NODEHOSTS" | sed 's/"/\\"/g')\"" -i "$BACKUP_FILE"

# Extract the last-applied-configuration annotation from the current configmap
LAST_APPLIED=$(kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE -o json | jq -r '.metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"]')

# If the annotation exists, add it to the backup file
if [ "$LAST_APPLIED" != "null" ]; then
  yq e ".metadata.annotations[\"kubectl.kubernetes.io/last-applied-configuration\"] = \"$LAST_APPLIED\"" -i "$BACKUP_FILE"
fi

# Apply the modified configmap
kubectl apply -f "$BACKUP_FILE"

# Restart CoreDNS pods to apply the new config
kubectl rollout restart deployment coredns -n $NAMESPACE

echo "CoreDNS NodeHosts updated and pods restarted successfully."

rm $BACKUP_FILE
