vsphere_server = "$VSPHERE_SERVER"
vsphere_user   = "$VSPHERE_USER"
vsphere_pass   = "$VSPHERE_PASSWORD"
datacenter     = "$VSPHERE_DATACENTER"
# Cluster needs to match VSPHERE_CLUSTER Environment variable
cluster           = "$VSPHERE_CLUSTER"
dvswitch          = "$VSPHERE_SWITCH"
vsphere_datastore = "$VSPHERE_DATASTORE"
iso_datastore     = "$VSPHERE_ISO_DATASTORE"
# Must have a snapshot
template          = "$VSPHERE_TEMPLATE"
folder            = "$VSPHERE_DATACENTER/vm"
domain            = "$DOMAIN"
default_portgroup = "$VSPHERE_PORTGROUP"
default_netmask   = "$DEFAULT_NETMASK"
default_gateway   = "$DEFUALT_GATEWAY"
dns_servers       = ["$DNS_01", "$DNS_02"]

vms = {
  crucible-ctrl-02 = {
    ip     = "$BASE_IP.160"
    cpus   = 4
    memory = 4096
    extra_config = {

    }
  },
  crucible-ctrl-03 = {
    ip     = "$BASE_IP.161"
    cpus   = 4
    memory = 4096
    extra_config = {

    }
  },
  crucible-wrkr-01 = {
    ip     = "$BASE_IP.162"
    cpus   = 4
    memory = 4096
    extra_config = {

    }
  },
  crucible-wrkr-02 = {
    ip     = "$BASE_IP.163"
    cpus   = 4
    memory = 4096
    extra_config = {

    }
  },
  crucible-wrkr-03 = {
    ip     = "$BASE_IP.164"
    cpus   = 4
    memory = 4096
    extra_config = {

    }
  },

}
