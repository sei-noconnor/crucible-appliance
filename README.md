# Crucible Appliance Deployment Guide

Welcome to the Crucible Appliance! This guide will walk you through deploying the appliance using the Makefile. The process is designed for system administrators and Linux admins familiar with command-line operations.

---

## Prerequisites

- **Host OS:** Linux (Ubuntu 22.04+ recommended)
- **Privileges:** sudo/root access
- **Dependencies:**  
  - Docker, Kubernetes tools (kubectl, kustomize), and other system dependencies will be installed by the Makefile
- **Network:** Outbound internet access for package and image downloads

---

## Repository Structure Overview

- `scripts/` – Shell scripts for system, certificate, and cluster management
- `packer/scripts/` – Scripts for appliance build, configuration, and snapshotting
- `argocd/` – ArgoCD manifests and overlays
- `Makefile` – Main entrypoint for all deployment and management tasks

---

## Quick Start: Deploying the Appliance

1. **Clone the Repository**

```

git clone https://github.com/sei-noconnor/crucible-appliance.git
cd crucible-appliance
cp appliance.yaml.example appliance.yaml

```

2. **Review and Edit Configuration (Optional)**
- The defaults for the appliance.yaml are suitable to get a running kubernetes cluster, however later application configs depend on a complete appliance.yaml file. If you have issues with the crucible applications coming up verify all values are configured in appliance.yaml

- Update the variables in `appliance.yaml` 

```yaml
vars:
  domain: crucible.io
  vsphere_server: vcsa.$DOMAIN
  vsphere_user: administrator@vsphere.local
  vsphere_password: P@ssw0rd123!@#
  vsphere_template: template
  vsphere_datacenter: datacenter
  vsphere_cluster: cluster
  vsphere_host: esxi.$DOMAIN
  vsphere_datastore: datastore
  vsphere_iso_datastore: iso
  vsphere_switch: DSwitch
  vsphere_portgroup: portgroup
  sudo_username: crucible
  sudo_password: crucible
  default_network: 10.x.x.x
  default_netmask: 255.255.255.0 #not CIDR
  default_gateway: 10.x.x.1
  dns_01: 10.x.x.11
  dns_02: 10.x.x.12
  docs_repo_secret: ~
```

3. **Full Initialization**

This command will:
- Generate and distribute certificates
- Install all OS and user dependencies
- Configure the system and hosts entries
- Initialize ArgoCD and Vault
- Set up Gitea (internal Git service)

```

make init

```

> **Tip:** This is the only command most users need for a standard deployment.

---

## Common Management Tasks

| Task                          | Command                                 | Description                                              |
|-------------------------------|-----------------------------------------|----------------------------------------------------------|
| Generate certificates         | `make certs`                            | Create and distribute root/K3s certificates              |
| Install dependencies          | `make deps`                             | Install system and user-level dependencies               |
| Configure system/hosts        | `make configure`                        | Setup hosts entries and user environment                 |
| Initialize ArgoCD             | `make argo-init`                        | Setup ArgoCD and dependencies                            |
| Reset ArgoCD                  | `make argo-reset`                       | Reset ArgoCD configuration                               |
| Initialize Gitea              | `make gitea-init`                       | Deploy and configure Gitea                               |
| Reset Gitea                   | `make gitea-reset`                      | Remove and reset Gitea                                   |
| Clean build artifacts         | `make clean`                            | Remove build and cache directories                       |
| Cluster expand/destroy        | `make cluster-manage ARGS=expand`       | Expand the Kubernetes cluster                            |
|                               | `make cluster-manage ARGS=destroy`      | Destroy the Kubernetes cluster                           |
| Vault unseal/configure/reset  | `make vault-manage ARGS=unseal`         | Unseal Vault                                             |
|                               | `make vault-manage ARGS=configure`      | Configure Vault                                          |
| Systemd service management    | `make systemd-manage ARGS=restart`      | Restart appliance systemd service                        |
|                               | `make systemd-manage ARGS=logs`         | View appliance startup logs                              |

---

## Detailed Workflow

### 1. Certificate Generation

Certificates are created and distributed to all necessary services:
```

make certs

```

### 2. System Preparation

Installs all required system packages and configures the host:
```

make deps
make configure

```

### 3. ArgoCD and Vault Initialization

Sets up GitOps workflow and secrets management:
```

make argo-init

```

### 4. Gitea Setup

Deploys the internal Git service and initializes repositories:
```

make gitea-init

```

### 5. Full Reset/Cleanup

To reset ArgoCD or Gitea, or to clean all build artifacts:
```

make argo-reset
make gitea-reset
make clean

```

---

## Advanced Operations

- **Cluster Management:**  
  Expand or destroy the Kubernetes cluster:
```

make cluster-manage ARGS=expand
make cluster-manage ARGS=destroy

```

- **Vault Management:**  
Unseal, configure, or reset Vault:
```

make vault-manage ARGS=unseal
make vault-manage ARGS=configure
make vault-manage ARGS=reset

```

- **Systemd Service Management:**  
Restart or view logs for the appliance service:
```

make systemd-manage ARGS=restart
make systemd-manage ARGS=logs

```

---

## Troubleshooting

- **Logs:**  
View logs with `make systemd-manage ARGS=logs` or check journalctl directly.
- **Snapshots:**  
Use your virtualization platform to snapshot the VM before/after major changes.
- **Secrets:**  
Vault is used for secrets management. Unseal or reset as needed with `make vault-manage`.

---

## Reference

For a full list of available Makefile commands, run:
```

make help

```

For more details on each script and its purpose, see the [scripts documentation](./makefile.md) or review the scripts in the `scripts/` and `packer/scripts/` directories.

---


