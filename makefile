# VARS
SHELL := /bin/bash
DOMAIN ?= crucible.local
SSH_USERNAME ?= crucible
ADMIN_PASS ?= crucible
SSL_DIR ?= dist/ssl
APPS_DIR ?= argocd/apps
ENVIRONMENT ?= DEV
export SSL_DIR
export APPS_DIR
export ADMIN_PASS

generate_certs:
	./scripts/generate_root_ca.sh
	./scripts/k3s-ca-gen.sh
	./scripts/distribute_certs.sh $(SSL_DIR)/server/tls
	
sudo-deps: generate_certs 
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/01-expand-volume.sh && \
	echo "${ADMIN_PASS}" | SSH_USERNAME="${SSH_USERNAME}" sudo -E -S bash ./packer/scripts/02-deps.sh

init: sudo-deps
	SSH_USERNAME="${SSH_USERNAME}" ./packer/scripts/04-user-deps.sh
	./packer/scripts/03-init-argo.sh
	
deps:
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/02-deps.sh

argo: 
	./packer/scripts/03-init-argo.sh
	
gitea:
	./packer/scripts/05-setup-gitea.sh

build:
	rm -rf ./packer/output && \
	rm -rf ./output && \
	rm -rf ./dist/output
	./packer/scripts/00-update-vars.sh ./appliance.yaml
	./packer/scripts/00-build-appliance.sh -on-error=abort -force

shrink:
	echo "${ADMIN_PASS}" | sudo -E -S ./scripts/shrink.sh

package-ova:
	./scripts/package-ova.sh

offline-reset:
	@echo "${ADMIN_PASS}" | sudo -S -E ./scripts/offline-reset.sh $(filter-out $@,$(MAKECMDGOALS))
%:
	@true

reset:
	./packer/scripts/98-reset-argo.sh

clean:
	rm -rf ./dist && \
	rm -rf ./cache
	rm -rf ./packer/output

clean-certs:
	rm -rf ./dist/ssl
	rm -rf ./argocd/apps/cert-manager/kustomize/base/files/{root-*,intermediate-*}

snapshot:
	@echo "${ADMIN_PASS}" | sudo -E -S ./packer/scripts/06-snapshot-etcd.sh $(filter-out $@,$(MAKECMDGOALS)) 
%:
	@true

keycloak-realm-export:
	./scripts/keycloak-realm-export.sh

tmp:
	echo "${ADMIN_PASS}" | sudo -E -S ./packer/scripts/tmp.sh
	

.PHONY: all clean clean-certs init build argo offline-reset reset snapshot

all: init