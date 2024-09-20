#!/bin/bash -x

# Set the namespace and configmap name for CoreDNS
NAMESPACE="kube-system"
CONFIGMAP_NAME="coredns"
DOMAIN=${2:-crucible.local}
IP=$(ip route get 1 | awk '{print $(NF-2);exit}')


if [ -z "$IP" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <ip> <domain>"
  exit 1
fi
# Backup the current configmap to a file
BACKUP_FILE="coredns-backup-$(date +%Y%m%d%H%M%S).yaml"
cat >$BACKUP_FILE <<EOF
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        hosts /etc/coredns/NodeHosts {
          ttl 60
          reload 15s
          fallthrough
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
        import /etc/coredns/custom/*.override
    }
    import /etc/coredns/custom/*.server
  NodeHosts: |
    192.168.1.66 crucible
    $IP $DOMAIN
kind: ConfigMap
metadata:
  name: coredns
EOF

# Apply the modified configmap
# kubectl delete cm -n kube-system coredns
kubectl apply -n $NAMESPACE -f "$BACKUP_FILE"

# Restart CoreDNS pods to apply the new config
kubectl rollout restart deployment coredns -n $NAMESPACE

echo "CoreDNS NodeHosts updated and pods restarted successfully."

rm $BACKUP_FILE
