## Expanding Cluster

Expanding a Crucible Appliance cluster involves four key phases: preparing a reusable VM template in vSphere, updating DNS, provisioning new nodes with Terraform, and configuring them via Ansible. Below is a step-by-step guide to ensure consistency and repeatability.

## Prerequisites

- vSphere credentials with rights to clone templates and create VMs
- Terraform (v1.0+) and the vSphere provider configured
- Ansible (v2.9+) installed and inventory (`inventory.yaml`) up to date
- `appliance.yaml` from the Crucible repo, including your target domain and `.cluster` definitions
- Access to the Crucible Git repository for Packer scripts

---

## Step 1: Create the vSphere Template VM

**1.1. Build a Base Ubuntu 22.04 VM**

| Resource  | Specification  |
|-----------|---------------|
| CPU       | 8 vCPUs       |
| RAM       | 12 GB         |
| OS Disk   | 50 GB         |
| Data Disk | ≥ 250 GB      |

**1.2. Install and Configure Software**

- Install `cloud-init` and `open-vm-tools`.
- Run OS-level app installs using the Packer script [`02-os-apps.sh`](https://${DOMAIN}/gitea/fortress-manifests/crucible-appliance/packer/scripts/02-os-apps.sh).
- Create the `crucible` user with passwordless sudo as defined in [`00-crucible-user.sh`](https://${DOMAIN}/gitea/fortress-manifests/crucible-appliance/packer/scripts/00-crucible-user.sh).
- Power off and take a snapshot of the VM. Name it "LinkedClone" or another identifier for clarity.

---

## Step 2: Update DNS Records

- Define cluster nodes in `appliance.yaml` under the `.cluster` key. Controllers should be deployed in odd numbers (1, 3, or 5).
- For each node, add an A record in your DNS management console. The DNS name is its key + domain `crucible-ctrl-01.onprem.twn-imcite.net`, and the IP is base_network + ip `192.168.1.15`.

Example:
```yaml
cluster:
  crucible-ctrl-01:
    ip: 15
    ...
  crucible-wrkr-01:
    ip: 18
    ...
```
DNS:
- `crucible-ctrl-01.onprem.twn-imcite.net` → `192.168.1.15`
- `crucible-wrkr-01.onprem.twn-imcite.net` → `192.168.1.18`

Verify DNS resolution:
```bash
dig +short crucible-ctrl-01.onprem.twn-imcite.net
```

---

## Step 3: Provision Nodes with Terraform

**3.1. Update `appliance.yaml`**

- Specify desired nodes and their roles under the `.cluster` key.

**3.2. Apply Terraform**

```bash
cd devops/terraform
terraform init
terraform plan       # Review planned changes
terraform apply -auto-approve
```
This process uses the vSphere provider to clone the template, set hostnames, configure networks, and power on new nodes.

---

## Step 4: Configure the Cluster via Ansible
The ansible inventory is created with the [ansible terriform provider](https://registry.terraform.io/providers/ansible/ansible/latest/docs)

**4.1. Verify Inventory**

```bash
ansible-inventory -i inventory.yaml --graph --vars
```
Ensure all new hosts appear under their groups.

**4.2. Run the Playbook**

```bash
ansible-playbook -i inventory.yaml deploy.yaml -K
```
This playbook configures Kubernetes and Crucible components on the new nodes.

**Note:** The script `scripts/cluster-expand.sh` is used internally to automate the addition of new nodes to the Kubernetes cluster and ensure all resources are provisioned and joined correctly[1].

---

## Step 5: Validate Expansion

- Check node status in Kubernetes:
  ```bash
  kubectl get nodes
  ```
- Confirm CoreDNS entries and service health:
  ```bash
  kubectl get pods -n kube-system
  ```
- Tail logs for troubleshooting:
  ```bash
  journalctl --follow --unit crucible-appliance-startup
  ```

---

## Additional Automation and Troubleshooting
- **Cluster Expansion:** Use `scripts/cluster-expand.sh` for manual expansion or troubleshooting if automation fails[1].
- **CoreDNS Updates:** The script `add-coredns-hosts-entry.sh` ensures internal DNS records are correct after expansion[1].
- **Logs:** Use `journalctl --unit crucible-appliance-startup` for startup issues

---
