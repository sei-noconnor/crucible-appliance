# =============================================
# Configuration & Variables
# =============================================
SHELL := /bin/bash
DOMAIN ?= crucible.io
ADMIN_PASS ?= crucible
SSL_DIR ?= dist/ssl
APPS_DIR ?= argocd/apps
APPLIANCE_IP ?= $(shell ip route get 1 | awk '{print $$(NF-2);exit}')

export DOMAIN ADMIN_PASS SSL_DIR APPS_DIR APPLIANCE_IP

# =============================================
# Phony Targets
# =============================================
.PHONY: help all init clean \
        certs deps configure \
        argo-init argo-reset \
        gitea-init gitea-reset \
        cluster-manage image-manage \
        vault-manage systemd-manage

# =============================================
# Main Targets
# =============================================
help:
	@echo "Crucible Appliance Management"
	@echo "Usage: make [target]"
	@echo ""
	@echo "Core:"
	@echo "  init        Full initialization (certs + deps + argo)"
	@echo "  clean       Remove all build artifacts"
	@echo ""
	@echo "Certificates:"
	@echo "  certs       Generate and distribute certificates"
	@echo ""
	@echo "System Setup:"
	@echo "  deps        Install OS and user dependencies"
	@echo "  configure   Configure system settings"
	@echo ""
	@echo "ArgoCD:"
	@echo "  argo-init   Initialize ArgoCD and dependencies"
	@echo "  argo-reset  Reset ArgoCD configuration"
	@echo ""
	@echo "Gitea:"
	@echo "  gitea-init  Initialize Gitea service"
	@echo "  gitea-reset Reset Gitea database and deployment"
	@echo ""
	@echo "Cluster:"
	@echo "  cluster-manage  Expand/destroy cluster (ARGS=action)"
	@echo ""
	@echo "Vault:"
	@echo "  vault-manage    Manage Vault (ARGS=action)"
	@echo ""
	@echo "Systemd:"
	@echo "  systemd-manage  Manage appliance service (ARGS=action)"

all: init

# =============================================
# Certificate Management
# =============================================
certs:
	@echo "Generating certificates..."
	./scripts/generate_root_ca.sh
	./scripts/k3s-ca-gen.sh
	./scripts/distribute_certs.sh $(SSL_DIR)

# =============================================
# System Setup
# =============================================
deps: certs
	@echo "Installing dependencies..."
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/02-os-vars.sh
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/02-os-configure.sh
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/02-os-apps.sh

configure:
	@echo "Configuring system..."
	./scripts/add-hosts-entry.sh -f /etc/hosts -r ${DOMAIN} -a upsert
	./packer/scripts/04-user-deps.sh

# =============================================
# ArgoCD Management
# =============================================
argo-init: certs
	@echo "Initializing ArgoCD..."
	./scripts/check-trusted-os-certs.sh -f $(SSL_DIR)/server/tls/root-ca.crt
	./scripts/add-coredns-hosts-entry.sh -n kube-system -c coredns-custom -r ${DOMAIN}
	./packer/scripts/03-argo-deps.sh
	./packer/scripts/03-init-argo.sh

argo-reset:
	@echo "Resetting ArgoCD..."
	./packer/scripts/98-reset-argo.sh

# =============================================
# Gitea Management
# =============================================
gitea-init:
	@echo "Initializing Gitea..."
	kubectl -n postgres exec appliance-postgresql-0 -- bash -c "PGPASSWORD=crucible psql -U postgres -c 'CREATE DATABASE gitea;'" || true
	kubectl kustomize ./argocd/install/gitea/kustomize/overlays/appliance | kubectl apply -f -
	sleep 10
	kubectl -n gitea scale deployment/appliance-gitea --replicas=0
	sleep 5
	kubectl -n gitea scale deployment/appliance-gitea --replicas=1
	./packer/scripts/05-setup-gitea.sh

gitea-reset:
	@echo "Resetting Gitea..."
	kubectl delete -n gitea --all resources
	kubectl -n postgres exec appliance-postgresql-0 -- bash -c "PGPASSWORD=crucible psql -U postgres -c 'DROP DATABASE gitea;'"

# =============================================
# Cluster Management
# =============================================
cluster-manage:
	@if [ -z "$(ARGS)" ]; then \
		echo "Usage: make cluster-manage ARGS='expand|destroy'"; \
		exit 1; \
	fi
	./scripts/cluster-$(ARGS).sh

# =============================================
# Vault Management
# =============================================
vault-manage:
	@if [ -z "$(ARGS)" ]; then \
		echo "Usage: make vault-manage ARGS='unseal|configure|reset'"; \
		exit 1; \
	fi
	./packer/scripts/09-vault-$(ARGS).sh

# =============================================
# Systemd Service Management
# =============================================
systemd-manage:
	@if [ -z "$(ARGS)" ]; then \
		echo "Usage: make systemd-manage ARGS='restart|logs|update'"; \
		exit 1; \
	fi
	@case "$(ARGS)" in \
		restart) systemctl restart crucible-appliance-startup ;; \
		logs) journalctl -u crucible-appliance-startup ;; \
		update) sudo cp ./packer/scripts/crucible-appliance-startup.sh /usr/local/bin/ ;; \
		*) echo "Invalid action"; exit 1 ;; \
	esac

# =============================================
# Cleanup
# =============================================
clean:
	@echo "Cleaning build artifacts..."
	rm -rf ./dist ./cache ./packer/output
	rm -rf ./argocd/install/*/files/*-id

init: deps configure argo-init gitea-init

# =============================================
# Argument Handling
# =============================================
%:
	@:
