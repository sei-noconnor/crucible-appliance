# VARS
SHELL := /bin/bash
DOMAIN ?= crucible.dev
ADMIN_PASS ?= ubuntu


generate_certs:
	./scripts/generate_certs.sh	crucible.dev -loglevel 3

init:
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/01-expand-volume.sh && \
	echo "${ADMIN_PASS}" | SSH_USERNAME=ubuntu sudo -E -S bash ./packer/scripts/02-deps.sh && \
	echo "${ADMIN_PASS}" | SSH_USERNAME=ubuntu sudo -E -S bash ./packer/scripts/03-init-argo.sh

argo: 
	echo "${ADMIN_PASS}" | SSH_USERNAME=ubuntu sudo -E -S bash ./packer/scripts/03-init-argo.sh

build:
	cd packer && \
	rm -rf output && \
	packer build -force -on-error=abort .

reset:
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/98-reset-argo.sh
	
clean:
	rm -rf ./dist && \
	rm -rf ./cache
	rm -rf ./packer/output

.PHONY: all clean init build argo reset

all: generate_certs