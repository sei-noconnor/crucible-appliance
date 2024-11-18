# VARS
SHELL := /bin/bash
DOMAIN ?= crucible.local
SSH_USERNAME ?= crucible
ADMIN_PASS ?= crucible
SSL_DIR ?= dist/ssl
APPS_DIR ?= argocd/apps
APPLIANCE_ENVIRONMENT ?= DEV
APPLIANCE_IP ?= $(ip route get 1 | awk '{print $(NF-2);exit}')
export SSL_DIR
export APPS_DIR
export ADMIN_PASS

generate_certs:
	./scripts/generate_root_ca.sh
	./scripts/k3s-ca-gen.sh
	./scripts/distribute_certs.sh $(SSL_DIR)
	
sudo-deps: generate_certs 
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/01-expand-volume.sh && \
	echo "${ADMIN_PASS}" | SSH_USERNAME="${SSH_USERNAME}" sudo -E -S bash ./packer/scripts/02-deps.sh

add-coredns-entry:
	./scripts/add-coredns-entry.sh "${APPLIANCE_IP}" "${DOMAIN}" $(filter-out $@,$(MAKECMDGOALS))
%:
	@true
	
init: sudo-deps add-coredns-entry
	SSH_USERNAME="${SSH_USERNAME}" ./packer/scripts/04-user-deps.sh
	make init-argo
	make snapshot
	
init-argo: 
	./packer/scripts/03-argo-deps.sh
	make unseal-vault
	./packer/scripts/03-init-argo.sh
	
init-vault:
	./packer/scripts/07-init-vault.sh

unseal-vault:
	./packer/scripts/09-unseal-vault.sh
	
init-gitea:
	./packer/scripts/05-setup-gitea.sh

build:
	rm -rf ./packer/output && \
	rm -rf ./output && \
	rm -rf ./dist/output
	./packer/scripts/00-update-vars.sh ./appliance.yaml
	./packer/scripts/00-build-appliance.sh $(filter-out $@,$(MAKECMDGOALS)) -on-error=abort -force
%:
	@true

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

deploy-runner:
	.github/runners/start.sh $(filter-out $@,$(MAKECMDGOALS))
%:
	@true	

delete-runner:
	.github/runners/start.sh -d $(filter-out $@,$(MAKECMDGOALS))
%:
	@true

uninstall:
	kubectl scale deployment --all -n gitea --replicas=0 || true
	kubectl scale deployment --all -n argocd --replicas=0 || true
	kubectl scale statefulsets --all -n argocd --replicas=0 || true
	kubectl scale statefulsets --all -n postgres --replicas=0 || true
	kubectl scale statefulsets --all -n vault --replicas=0 || true
	sleep 10
	kubectl -n longhorn-system patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag || true
	kubectl -n longhorn-system delete job longhorn-uninstall || true
	kubectl -n longhorn-system delete serviceaccount longhorn-uninstall-service-account || true
	kubectl delete clusterrole longhorn-uninstall-role || true
	kubectl delete clusterrolebinding longhorn-uninstall-bind || true
	kubectl create -f ./argocd/install/longhorn/kustomize/base/files/uninstall-longhorn.yaml
	sleep 60
	echo "${ADMIN_PASS}" | sudo -E -S k3s-uninstall.sh && sudo rm -rf /tmp/crucible-appliance || true
	sudo rm -rf /var/lib/longhorn
	sudo rm -rf /dev/longhorn

startup-logs:
	sudo cat /var/log/syslog | grep crucible-appliance

tmp:
	echo "${ADMIN_PASS}" | sudo -E -S ./packer/scripts/tmp.sh
	

.PHONY: all clean clean-certs init build argo offline-reset reset snapshot package-ova

all: init