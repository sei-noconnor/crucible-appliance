vsphere_server = "${VSPHERE_SERVER}"
vsphere_user   = "${VSPHERE_USER}"
vsphere_pass   = "${VSPHERE_PASSWORD}"
datacenter     = "${VSPHERE_DATACENTER}"
# Cluster needs to match VSPHERE_CLUSTER Environment variable
cluster           = "${VSPHERE_CLUSTER}"
dvswitch          = "${VSPHERE_SWITCH}"
vsphere_datastore = "${VSPHERE_DATASTORE}"
iso_datastore     = "${VSPHERE_ISO_DATASTORE}"
# Must have a snapshot
template          = "${VSPHERE_TEMPLATE}"
folder            = "${VSPHERE_DATACENTER}/vm"
domain            = "${DOMAIN}"
default_portgroup = "${VSPHERE_PORTGROUP}"
default_netmask   = "${DEFAULT_NETMASK}"
default_gateway   = "${DEFAULT_GATEWAY}"
dns_servers       = ["${DNS_01}"]

vms = {}
