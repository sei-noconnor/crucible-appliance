## High-Level Architecture of the Crucible Appliance

The Crucible Appliance is structured as a self-contained, VM-deployable solution that orchestrates a suite of open-source tools and services for secure, automated software delivery. Its architecture is modular, leveraging Kubernetes as the core orchestration layer and integrating several key components for certificate management, secrets, CI/CD, and internal code hosting.

**Key Architectural Components**

- **Operating System Layer**
  - The appliance image is built with OS-level dependencies and configurations, including environment variables, network setup, user management, and required applications[1].
  - System initialization scripts ensure the appliance domain is configured and all essential services are resolvable via internal DNS using CoreDNS and /etc/hosts entries[1].

- **Kubernetes Cluster (K3s)**
  - The appliance runs a lightweight Kubernetes distribution (K3s) as its core orchestration platform[1].
  - Kubernetes manages the lifecycle of all internal services and applications.

- **Storage (Longhorn)**
  - Longhorn is deployed as the storage solution for the Kubernetes cluster, providing persistent storage for applications and services
  - The appliance is configured to use Longhorn for all internal storage needs, ensuring data persistence across reboots and failures


- **Certificate Authority & SSL Management**
  - Custom scripts generate a new root CA, create the K3s CA, and distribute certificates to the configured SSL directory, establishing trust for both internal and external communications[1].
  - Additional scripts ensure the appliance CA is trusted by the OS and all services[1].

- **Secrets Management (HashiCorp Vault)**
  - Vault is initialized and unsealed as part of the appliance setup, providing secure storage and management of secrets[1].
  - Application-specific variables and roles are configured in Vault for integration with other services like ArgoCD[1].

- **Git Service (Gitea)**
  - Gitea is deployed as the internal Git hosting service, with its own PostgreSQL database[1].
  - Repositories are initialized and managed via manifest-driven scripts, supporting both backup/export and restore/import of container images[1].

- **Continuous Delivery (ArgoCD)**
  - ArgoCD is set up for GitOps-based deployment and management of applications within the appliance[1].
  - Integration with Vault allows ArgoCD to retrieve secrets securely for deployments[1].

- **Identity and Access Management (Keycloak)**
  - Keycloak is deployed for authentication and authorization, with export/import scripts for realm configuration management[1].

- **CI/CD Integration**
  - The appliance can deploy and manage self-hosted GitHub Actions runners for CI/CD tasks[1].

- **Lifecycle and Maintenance Utilities**
  - Scripts enable snapshotting of the VM, resetting or cleaning the appliance, expanding/destroying the Kubernetes cluster, and packaging the appliance as an OVA for distribution[1].

## Component Overview Table

| Component                | Purpose/Role                                                                                 |
|--------------------------|---------------------------------------------------------------------------------------------|
| OS Layer                 | Installs base OS, configures environment, networking, and users                             |
| K3s (Kubernetes)         | Orchestrates all internal services and applications                                         |
| Certificate Management   | Generates and manages root CA, distributes and checks certificates                          |
| HashiCorp Vault          | Manages secrets and sensitive variables for applications                                    |
| Gitea                    | Internal Git hosting, repository management, backup/restore of images                       |
| ArgoCD                   | GitOps continuous delivery and application lifecycle management                             |
| Keycloak                 | Identity and access management, realm configuration export/import                           |
| CoreDNS                  | Internal DNS resolution for appliance services                                              |
| Gitea/Github Actions Runner    | Self-hosted runners for CI/CD workflows                                                     |
| Maintenance Scripts      | snapshot, appliance reset/clean, cluster expansion/destruction, OVA packaging            |

