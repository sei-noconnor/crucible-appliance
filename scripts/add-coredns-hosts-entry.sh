#!/bin/bash
# This script updates CoreDNS ConfigMap with custom host entries and restarts CoreDNS pods to apply changes.
#
# Default values:
#   NAMESPACE="kube-system"
#   CONFIGMAP_NAME="coredns-custom"
#   ACTION="upsert"
#
# Usage:
#   ./add-coredns-hosts-entry.sh [-n|--namespace <namespace>] [-c|--configmap_name <configmap_name>] [-r|--records <record1,record2,...>] [-a|--action <action>] [-h|--help]
#
# Options:
#   -n, --namespace        Set the namespace for CoreDNS (default: kube-system)
#   -c, --configmap_name   Set the configmap name for CoreDNS (default: coredns-custom)
#   -r, --records          Set the records (comma-separated, default: crucible.io)
#   -a, --action           Set the action (upsert, delete) (default: upsert)
#   -h, --help             Display this help message
#
# Example:
#   ./add-coredns-hosts-entry.sh -n kube-system -c coredns-custom -r example.com,example.org -a upsert
#
# The script performs the following steps:
# 1. Parses command-line options.
# 2. Retrieves the current CoreDNS ConfigMap or creates a new one if it doesn't exist.
# 3. Updates or deletes host entries in the ConfigMap based on the specified action.
# 4. Removes duplicate entries from the ConfigMap.
# 5. Applies the modified ConfigMap using kubectl.
# 6. Restarts CoreDNS pods to apply the new configuration.
# 7. Cleans up temporary files.


# Default values
NAMESPACE="kube-system"
CONFIGMAP_NAME="coredns-custom"
ACTION="upsert"

# Usage function
usage() {
    echo "Usage: $0 [-n|--namespace <namespace>] [-c|--configmap_name <configmap_name>] [-r|--records <record1,record2,...>] [-a|--action <action>] [-h|--help]"
    echo "  -n, --namespace        Set the namespace for CoreDNS (default: kube-system)"
    echo "  -c, --configmap_name   Set the configmap name for CoreDNS (default: coredns-custom)"
    echo "  -r, --records          Set the records (comma-separated, default: onprem.phl-imcite.net)"
    echo "  -a, --action           Set the action (upsert, delete) (default: upsert)"
    echo "  -h, --help             Display this help message"
    echo ""
    echo "Example: $0 -n kube-system -c coredns-custom -r example.com,example.org -a upsert"
    exit 1
}

# Parse options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift ;;
        -c|--configmap_name) CONFIGMAP_NAME="$2"; shift ;;
        -r|--records) IFS=',' read -r -a RECORDS <<< "$2"; shift ;;
        -a|--action) ACTION="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

CONFIGMAP_FILE="/tmp/core-dns-$RANDOM.yaml"
IP=$(ip route get 1 | awk '{print $(NF-2);exit}')

export IP=$IP
export CONFIGMAP_NAME=$CONFIGMAP_NAME

# Get the config file or create it
YAML=$(kubectl -n $NAMESPACE get cm $CONFIGMAP_NAME -o yaml --ignore-not-found)
if [ -n "$YAML" ]; then 
  echo "$YAML" > "$CONFIGMAP_FILE"
  echo "Debug: Existing ConfigMap found and saved to $CONFIGMAP_FILE"
else
  # create file then process
  TMPL="$(cat <<EOF
apiVersion: v1
data:
  hosts.server: |
    onprem.phl-imcite.net:53 {
      log
      errors
      hosts {
        $IP ${RECORDS[0]}
        fallthrough
      }
    }
kind: ConfigMap
metadata:
  name: $CONFIGMAP_NAME
EOF
)"
  echo "File not found, creating."
  echo "$TMPL" > "$CONFIGMAP_FILE"
  echo "Debug: New ConfigMap template created and saved to $CONFIGMAP_FILE"
fi

# Perform the specified action only on the hosts section
for RECORD in "${RECORDS[@]}"; do
    case $ACTION in
        upsert)
            if grep -q "        $IP $RECORD" "$CONFIGMAP_FILE"; then
                echo "Debug: Entry for $RECORD already exists, updating."
                sed -i "/hosts {/!b;n;c\\        $IP $RECORD" "$CONFIGMAP_FILE"
            else
                echo "Debug: Adding new entry for $RECORD."
                sed -i "/hosts {/a\\        $IP $RECORD" "$CONFIGMAP_FILE"
            fi
            ;;
        delete)
            if grep -q "        $IP $RECORD" "$CONFIGMAP_FILE"; then
                echo "Debug: Deleting entry for $RECORD."
                sed -i "/hosts {/!b;n;/        $IP $RECORD/d" "$CONFIGMAP_FILE"
            else
                echo "Debug: Entry for $RECORD does not exist."
            fi
            ;;
        *)
            echo "Unknown action: $ACTION"
            usage
            ;;
    esac
done

# Remove duplicate entries
awk '!seen[$0]++' "$CONFIGMAP_FILE" > "$CONFIGMAP_FILE.tmp" && mv "$CONFIGMAP_FILE.tmp" "$CONFIGMAP_FILE"

# process the file
cat "$CONFIGMAP_FILE"

# Apply the modified configmap
k3s kubectl apply -n $NAMESPACE -f "$CONFIGMAP_FILE"
echo "Debug: Applied ConfigMap $CONFIGMAP_FILE"

# Restart CoreDNS pods to apply the new config
k3s kubectl rollout restart deployment coredns -n $NAMESPACE
echo "Debug: Restarted CoreDNS pods"

echo "CoreDNS NodeHosts updated and pods restarted successfully."

#cleanup
rm -rf $CONFIGMAP_FILE
echo "Debug: Cleaned up temporary file $CONFIGMAP_FILE"
