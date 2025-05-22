Architecture

Overview

The Crucible Appliance architecture condenses an enterprise‑grade DevSecOps stack into a single virtual machine. A hardened Ubuntu host boots a K3s control plane, which in turn orchestrates:

Platform services (Ingress‑NGINX, Longhorn, cert‑manager) for ingress, persistent storage, and automated internal TLS.

Core services (Keycloak, Vault, Gitea, Argo CD) that provide identity, secrets, source control, and GitOps automation.

Crucible training suite	(Player, Caster, Alloy, Steamfitter, Blueprint, Cite, Gallery, TopoMojo, Gameboard) – Player–Caster–Alloy–Steamfitter–Blueprint–Cite–Gallery form an integrated workflow, while TopoMojo pairs with Gameboard for scenario orchestration and scoring.

All endpoints flow through Ingress‑NGINX under the wildcard domain *.crucible.io, giving the VM a uniform, TLS‑terminated surface area.

Core Components

Host OS – Ubuntu LTSHardened base image with containerd and systemd units that bootstrap K3s and run appliance management scripts.

Kubernetes – K3sLightweight Kubernetes distribution with embedded etcd; orchestrates every workload in the appliance.

Platform ServicesIngress‑NGINX, Longhorn, and cert‑manager provide HTTPS termination, persistent storage, and automated internal TLS.

Core ServicesKeycloak, Vault, Gitea, and Argo CD deliver identity, secrets management, Git hosting, and GitOps‑based continuous deployment.

Crucible SuiteThe training applications—Player, Caster, Alloy, Steamfitter, Blueprint, Cite, Gallery, TopoMojo, and Gameboard—power end‑to‑end lab delivery. Player, Caster, Alloy, Steamfitter, Blueprint, Cite, and Gallery work together in a single workflow, whereas TopoMojo integrates with Gameboard for scenario orchestration and scoring.