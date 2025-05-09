# Crucible Appliance Makefile Documentation

## Core Commands

| Command       | Parameters          | Description                                  | Example                     |
|---------------|---------------------|----------------------------------------------|-----------------------------|
| `make init`   | None                | Full initialization (certs + deps + Argo)   | `make init`                 |
| `make clean`  | None                | Remove all build artifacts                   | `make clean`                |

## Certificate Management

| Command       | Parameters          | Description                                  | Example                     |
|---------------|---------------------|----------------------------------------------|-----------------------------|
| `make certs`  | None                | Generate root/K3s certs and distribute       | `make certs`                |

## System Setup

| Command           | Parameters          | Description                                  | Example                     |
|-------------------|---------------------|----------------------------------------------|-----------------------------|
| `make deps`       | None                | Install OS-level dependencies               | `make deps`                 |
| `make configure`  | None                | Configure system settings and hosts         | `make configure`            |

## ArgoCD Management

| Command           | Parameters          | Description                                  | Example                     |
|-------------------|---------------------|----------------------------------------------|-----------------------------|
| `make argo-init`  | None                | Initialize ArgoCD and dependencies          | `make argo-init`            |
| `make argo-reset` | None                | Reset ArgoCD configuration                  | `make argo-reset`           |

## Gitea Management

| Command           | Parameters          | Description                                  | Example                     |
|-------------------|---------------------|----------------------------------------------|-----------------------------|
| `make gitea-init` | None                | Initialize Gitea service                    | `make gitea-init`           |
| `make gitea-reset`| None                | Reset Gitea database and deployment         | `make gitea-reset`          |

## Cluster Management

| Command               | Parameters          | Description                                  | Example                     |
|-----------------------|---------------------|----------------------------------------------|-----------------------------|
| `make cluster-manage` | ARGS=action         | Cluster operations (expand/destroy)         | `make cluster-manage ARGS=expand` |

## Vault Management

| Command               | Parameters          | Description                                  | Example                     |
|-----------------------|---------------------|----------------------------------------------|-----------------------------|
| `make vault-manage`   | ARGS=action         | Vault operations (unseal/configure/reset)   | `make vault-manage ARGS=unseal` |

## Systemd Service Management

| Command               | Parameters          | Description                                  | Example                     |
|-----------------------|---------------------|----------------------------------------------|-----------------------------|
| `make systemd-manage` | ARGS=action         | Manage appliance service                    | `make systemd-manage ARGS=restart` |

---

## Key Improvements Over Original

1. **Modular Structure**  
   - Grouped related targets into logical sections (certificates, ArgoCD, Gitea, etc)
   - Separated configuration variables from implementation

2. **Self-Documenting**  
   - Built-in `help` target shows available commands
   - Clear parameter expectations for complex targets

3. **Simplified Workflow**  
   - Single `init` target handles full setup
   - Parameterized targets (`cluster-manage`, `vault-manage`) reduce redundancy

4. **Safety**  
   - Added guard clauses for required parameters
   - Explicit cleanup targets

5. **Consistency**  
   - Uniform naming convention (`*-manage` for parameterized targets)
   - Standardized script calling patterns

---

## Usage Example

**Typical Deployment:**
