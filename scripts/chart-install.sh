#!/bin/bash
if [ -f ./appliance.yaml ]; then
  source ./packer/scripts/lib/functions.sh
  yaml_to_env "./appliance.yaml"
fi

TMP_DIR=$(mktemp -d)
cat <<EOF > config.patch
- op: add
  path: /cluster/apiServer/admissionControl/0/configuration/exemptions/namespaces/-
  value: longhorn-system
EOF

CLUSTER_NAME=talos-default

# talosctl cluster create --name $CLUSTER_NAME --talosconfig talosconfig --config-patch-control-plane @$TMP_DIR/control.patch --config-patch-worker @$TMP_DIR/config.patch --force
# talosctl config nodes 10.5.0.2 10.5.0.3 --talosconfig talosconfig
# talosctl patch mc --patch @controlplane.yaml --nodes 10.5.0.2 --talosconfig talosconfig
# talosctl patch mc --patch @worker.yaml --nodes 10.5.0.3 --talosconfig talosconfig
# export GOVC_URL="${VCENTER_URL}"
# export GOVC_USERNAME="${VCENTER_USER}"
# export GOVC_PASSWORD="${VCENTER_PASSWORD}"
# export GOVC_INSECURE=truedocker ps 
# export GOVC_DATACENTER="${VCENTER_DATACENTER}"
# export GOVC_DATASTORE="${VCENTER_DATASTORE}"
# export GOVC_NETWORK="${VCENTER_PORTGROUP}"
# helmfile sync --skip-deps 

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

helmfile sync --skip-deps