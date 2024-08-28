# VARS
SHELL := /bin/bash
DOMAIN ?= crucible.dev
ADMIN_PASS ?= ubuntu
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
	
init: generate_certs
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/01-expand-volume.sh && \
	echo "${ADMIN_PASS}" | SSH_USERNAME=ubuntu sudo -E -S bash ./packer/scripts/02-deps.sh && \
	bash ./packer/scripts/03-init-argo.sh

argo: 
	bash ./packer/scripts/03-init-argo.sh

build:
	rm -rf ./packer/output && \
	rm -rf ./output && \
	./packer/scripts/04-update-vars.sh
	packer init ./packer && \ 
	packer build -force -on-error=abort ./packer

reset:
	bash ./packer/scripts/98-reset-argo.sh

clean:
	rm -rf ./dist && \
	rm -rf ./cache
	rm -rf ./packer/output

clean-certs:
	rm -rf ./dist/ssl
	rm -rf ./argocd/apps/cert-manager/kustomize/base/files/{root-*,intermediate-*}

.PHONY: all clean clean-certs init build argo reset

all: init