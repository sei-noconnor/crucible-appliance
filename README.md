# Crucible Appliance

This repository contains the Packer configuration and scripts necessary to build a Crucible virtual appliance in OVF format. The appliance is designed to be portable and easily deployed.

## Features

- **SSO Authentication (Keycloak):** Integrated Keycloak for secure single sign-on authentication across the appliance's services.
- **Git Server (Gitea):** Embedded Gitea server for streamlined in-cluster version control and collaboration.
- **Cert-Manager:** Utilizes cert-manager to automate certificate management, including the use of a "crucible.local" root CA.
- **CI/CD (ArgoCD):** Enables continuous integration and continuous deployment with ArgoCD for seamless application updates and rollbacks.
- **Offline Registry Cache:** Leverages the built-in registry cache of k3s to support offline deployments and reduce dependencies on external registries.

## Prerequisites

#### OS Packages:

- build-essential
- dnsmasq
- avahi-daemon
- jq
- nfs-common
- sshpass
- postgresql-client
- make

#### External Tools/Dependencies:

- yq (installed from GitHub releases)
- k3s (installed using curl from https://get.k3s.io)
- kubectl (installed from Kubernetes release)
- helm (installed using the get-helm-3 script)
- k9s (installed from .deb package)
- argocd-cli (installed from Argo CD releases)

## Getting Started

1. Clone the Repository:

   ```bash
   git clone [https://github.com/your-username/packer-appliance-ovf.git](https://github.com/your-username/packer-appliance-ovf.git)
   cd packer-appliance-ovf
   ```

## Build

## Building the Appliance

The Crucible appliance is tested on vSphere 8, ensuring seamless compatibility and optimal performance. to start with Crucible, follow these steps:

1. **Copy the Variable File:**
   ```bash
   cp appliance.yaml.example appliance.yaml
   ```
2. **Customize Your Environment:**
   Open the appliance.yaml file and tailor the variables to align with your specific vSphere environment configuration.
   ```yaml
	vars:
		vsphere_server: vcsa.example.com
		vsphere_user: administrator@vsphere.local
		vsphere_password: pasword1234!@
		datacenter: Datacenter1
		cluster: Cluster1
		datastore: ds1
		network_name: "VM Network"`
	```
3. **Initiate the Build:**

   ```bash
   make build
   ```

4. **Import into vSphere:**
   Upon successful completion of the Packer build process, an OVF directory will be located the ./output folder. Import this OVF into your vSphere environment.

## Makefile Documentation

| Target                  | Dependencies     | Description                                                     | 
| ----------------------- | ---------------- | --------------------------------------------------------------- | 
| `generate_certs`        |                  | Generates root CA and K3s CA certificates, distributes certs.   | 
| `sudo-deps`             | `generate_certs` | Expands volume, installs sudo dependencies, configures netplan. | 
| `init`                  | `sudo-deps`      | Installs user dependencies, initializes Argo.                   | 
| `deps`                  |                  | Installs sudo dependencies.                                          | 
| `argo`                  |                  | Initializes Argo.                                               | 
| `gitea`                 |                  | Sets up Gitea.                                                  | 
| `build`                 |                  | Cleans output directories, updates variables, builds appliance. | 
| `offline-reset`         |                  | Performs an offline reset     | 
| `reset`                 |                  | Resets Argo.                                                    | 
| `clean`                 |                  | Removes build artifacts and cache.                              | 
| `clean-certs`           |                  | Removes root and intermediate SSL certificates.                                       | 
| `snapshot`              |                  | Takes a manual etcd snapshot (prefix: crucible-appliance)         | 
| `keycloak-realm-export` |                  | Exports the Keycloak realm.                                     | 

### Install the OVFTool from VMWare

1. download and install the OVFTool from VMware [ovftool](https://developer.broadcom.com/tools/open-virtualization-format-ovf-tool/latest)
1. Install it based on the [instructions](https://docs.vmware.com/en/VMware-Telco-Cloud-Operations/1.3.0/deployment-guide-130/GUID-95301A42-F6F6-4BA9-B3A0-A86A268754B6.html).