Crucible Appliance - Argo
This is a reop to provision a Crucible appliance by way of argocd manifest and git repositories.

## Features

SSO Authentication Keycloak (dod CAC enabled)
Git Server for in-cluster operations
cert-manager for certificate (uses crucible.local root-ca)
argocd - continuous deployment

## Makefile

| Command        | Description                                                                                                 |
| :------------- | :---------------------------------------------------------------------------------------------------------- |
| generate_certs | Creates certificates                                                                                        |
| sudo_deps      | scripts and configurations that need to be run with elevated privledges such as sudo or root                |
| init           | Full build process fresh ubuntu 22.04                                                                       |
| deps           | runs only the deps script for development                                                                   |
| argo           | runs only the argo script                                                                                   |
| build          | will build the appliance with packer and vpshere                                                            |
| offline-reset  | restores a snapshot, takes a prefix for snapshot name (default: "filename=\*")                              |
| reset          | resets the argo install                                                                                     |
| clean          | unsused - suppose to clean everythin including certificates                                                 |
| snapshot       | takes etcd snapshot of k3s state. takes a prefix for snapshot name (default: "filename=crucible-appliance") |
| tmp            | dev task for testing scripts                                                                                |

```
# VARS
SHELL := /bin/bash
DOMAIN ?= crucible.local
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
	echo "${ADMIN_PASS}" | SSH_USERNAME=ubuntu sudo -E -S bash ./packer/scripts/02-deps.sh
	SSH_USERNAME=ubuntu ./packer/scripts/03-user-deps.sh
	./packer/scripts/03-init-argo.sh

deps:
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/02-deps.sh

argo:
	bash ./packer/scripts/03-init-argo.sh

build:
	rm -rf ./packer/output && \
	rm -rf ./output && \
	./packer/scripts/04-update-vars.sh ./appliance.yaml
	./packer/scripts/00-build-appliance.sh -on-error=abort -force

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
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/05-snapshot-etcd.sh


.PHONY: all clean clean-certs init build argo reset snapshot

all: init
```

## Dependencies

- install ovftool
- packer
- k3s
- helm
- kubectl
- ovftool
- make

## Building the appliance

building the image is done with packer. you will need a remote vsphere server or ESXi host to build this image.

copy the variable file `cp ./packer/vars.auto.pkrvars.hcl.example ./packer/vars.auto.pkrvars.hcl` and modify the values to match your environment

## Steps

### Install the OVFTool from VMWare

1. download and install the OVFTool from VMware [ovftool](https://developer.broadcom.com/tools/open-virtualization-format-ovf-tool/latest)
1. Install it based on the [instructions](https://docs.vmware.com/en/VMware-Telco-Cloud-Operations/1.3.0/deployment-guide-130/GUID-95301A42-F6F6-4BA9-B3A0-A86A268754B6.html).

## argocd

We want to manage the cluster with argocd so that simple patches from git repositories can be imported and used in an offline environment.
