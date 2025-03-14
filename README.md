# Crucible Appliance

This repository contains the configuration and scripts needed to build a Crucible virtual appliance in OVF format. The Crucible Appliance is a portable, easily deployable solution designed for secure, efficient, and offline-capable deployments in a vSphere environment.

## Table of Contents

1. [Features](#features)
2. [Prerequisites](#prerequisites)
3. [Getting Started](#getting-started)
4. [Build](#build)
5. [Makefile Documentation](#makefile-documentation)
6. [Usage](#usage)
7. [Contributing](#contributing)
8. [License](#license)

## Features

- **SSO Authentication (Keycloak):** Secure and centralized authentication across all services within the appliance, simplifying user management.
- **Git Server (Gitea):** Embedded Gitea server for streamlined in-cluster version control and collaboration.
- **Cert-Manager:** Automates certificate management, including the use of a "crucible.io" root CA, ensuring secure communication.
- **CI/CD (ArgoCD):** Enables continuous integration and continuous deployment with ArgoCD for seamless application updates and rollbacks.
- **Offline Registry Cache:** Utilizes the built-in registry cache of k3s to support offline deployments, reducing dependencies on external registries.

## Prerequisites

### OS Packages

Install the following OS packages on your machine: (These are installed with `make init`)

- **build-essential:** Install with `sudo apt-get install build-essential`
- **dnsmasq:** Install with `sudo apt-get install dnsmasq`
- **avahi-daemon:** Install with `sudo apt-get install avahi-daemon`
- **jq:** Install with `sudo apt-get install jq`
- **nfs-common:** Install with `sudo apt-get install nfs-common`
- **sshpass:** Install with `sudo apt-get install sshpass`
- **postgresql-client:** Install with `sudo apt-get install postgresql-client`
- **make:** Install with `sudo apt-get install make`

### External Tools/Dependencies

Install the following external tools: (These are installed with `make init`)

- **yq:** Install from [GitHub releases](https://github.com/mikefarah/yq/releases)
- **k3s:** Install using `curl -sfL https://get.k3s.io | sh -`
- **kubectl:** Install from [Kubernetes release](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- **helm:** Install using the [get-helm-3 script](https://helm.sh/docs/intro/install/)
- **k9s:** Install from the [.deb package](https://github.com/derailed/k9s/releases)
- **argocd-cli:** Install from [Argo CD releases](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

## Getting Started
Absent a proper packer build environment the appliance can be instantiated with a standard ubuntu 22.04 vm. 
1. Configure a VM with 
  - cpu : 8
  - memory: 12GB
  - disk: +50GB

some of the code is still dependent on a `crucible` user

1. create and configure the crucible user
  - `sudo adduser crucible`
  - `sudo usermod -aG sudo`
  - `sudo passwd crucible`
1. log out and log back in as `crucible`
1. install make 
`sudo apt-get install make`

1. clone the repo `git clone https://github.com/sei-noconnor/crucible-appliance.git`
1. cd crucible-appliance
1. run `make init`

depending on your internet connection the appliance takes about 20 minutes to provision.

1. create an entry in dns or in your local hosts file for the domain
```
<ip> crucible.io cd.crucible.io keystore.crucible.io vault.crucible.io
```

## Packer Build

### Building the Appliance

The Crucible appliance is tested on vSphere 8, ensuring seamless compatibility and optimal performance. To start with Crucible, follow these steps:

1.  **Copy the Variable File:**

    ```bash
      `cp appliance.example.yaml appliance.yaml`
    ```


2.  **Customize Your Environment:**

 Modify the `appliance.yaml` file to match your environment. This includes setting the vSphere server, user credentials, datacenter, cluster, datastore, and network details. Ensure these settings match your vSphere configuration to avoid deployment errors.

 ```yaml
   vars:
  domain: crucible.io
  vsphere_server: vcsa.crucible.io
  vsphere_user: administrator@vsphere.local
  vsphere_password:
  vsphere_template:
  vsphere_datacenter:
  vsphere_cluster:
  vsphere_host:
  vsphere_datastore:
  vsphere_iso_datastore:
  vsphere_switch: 
  vsphere_portgroup:
  sudo_username: crucible
  sudo_password: crucible
  default_network:
  default_netmask:
  default_gateway:
  dns_01:
  dns_02:
  
cluster:
  crucible-ctrl-02:
    ip:
    cpus:
    memory:
    extra_config: {}
  crucible-ctrl-03:
    ip:
    cpus:
    memory:
    extra_config: {}
  crucible-wrkr-01:
    ip:
    cpus:
    memory:
    extra_config: {}
  crucible-wrkr-02:
    ip:
    cpus:
    memory:
    extra_config: {}
  crucible-wrkr-03:
    ip:
    cpus:
    memory:
    extra_config: {}
apps:
features:
  # Allows the appliance to work in an air-gapped environment by downloading 
  # containers, charts, binary packages and and OS packages required 
  # values: [true, false]
  airgap_mode: true

  # Enables a set of gitea actions to create packer images, and cluster,
  # dependancies to extend the default single node appliance to a full 
  # k3s cluster.
  # values : [true, false]
  cluster_builder: true

  # Allows the appliance to use a private registry or registry mirror that 
  # already exists on your network. This helps with docker pull limits. 
  # value: https://<registry_url>:<registry_port>
  private_registry:

```

3.  **Initiate the Build:**

```bash
   make build
```

4.  **Import into vSphere:**

    Upon successful completion of the Packer build process, an OVF directory will be located in the `./dist/output` folder. Import this OVF into your vSphere environment.

## Makefile Documentation

| Target                  | Dependencies     | Description                                                                                    |
| ----------------------- | ---------------- | ---------------------------------------------------------------------------------------------- |
| `generate_certs`        |                  | Generates root CA and K3s CA certificates, distributes certs.                                  |
| `sudo-deps`             | `generate_certs` | Expands volume, installs sudo dependencies, configures netplan.                                |
| `init`                  | `sudo-deps`      | Installs user dependencies, initializes Argo. This script provisions a base 22.04 ubuntu image |
| `deps`                  |                  | Installs sudo dependencies.                                                                    |
| `argo`                  |                  | Initializes Argo.                                                                              |
| `gitea`                 |                  | Sets up Gitea.                                                                                 |
| `build`                 |                  | Cleans output directories, updates variables, builds appliance.                                |
| `offline-reset`         |                  | Performs an offline reset.                                                                     |
| `reset`                 |                  | Resets Argo.                                                                                   |
| `clean`                 |                  | Removes build artifacts and cache.                                                             |
| `clean-certs`           |                  | Removes root and intermediate SSL certificates. So new ones can be generated                   |
| `snapshot`              |                  | Takes a manual etcd snapshot (prefix: crucible-appliance).                                     |
| `keycloak-realm-export` |                  | Exports the Keycloak realm.                                                                    |

## Usage

Once deployed, access the Start page at [https://crucible.io](https://crucible.io)

## Contributing

Contributions are welcome! Please see the [DEVELOPMENT.md](./DEVELOPMENT.md) README for detailed instructions

## License

This project is licensed under the MIT License - see the LICENSE file for details.

### Install the OVFTool from VMware
The OVF tool is now hosted behind a login, you'll need to install the OVFTool if you want to convert from OVF format to OVA.

1.  Download and install the OVFTool from VMware [ovftool](https://developer.broadcom.com/tools/open-virtualization-format-ovf-tool/latest).
2.  Install it based on the [instructions](https://docs.vmware.com/en/VMware-Telco-Cloud-Operations/1.3.0/deployment-guide-130/GUID-95301A42-F6F6-4BA9-B3A0-A86A268754B6.html).
