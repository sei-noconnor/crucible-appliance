# VARS
SHELL := /bin/bash
DOMAIN ?= crucible.io
SSH_USERNAME ?= crucible
ADMIN_PASS ?= crucible
SSL_DIR ?= /home/crucible/crucible-appliance/dist/ssl
APPS_DIR ?= argocd/apps
APPLIANCE_ENVIRONMENT ?= DEV
APPLIANCE_IP ?= $(ip route get 1 | awk '{print $(NF-2);exit}')

export SSL_DIR
export APPS_DIR
export ADMIN_PASS
export DOMAIN


generate_certs:
	./scripts/generate_root_ca.sh
	./scripts/k3s-ca-gen.sh
	./scripts/distribute_certs.sh $(SSL_DIR)
	
sudo-deps: generate_certs 
	echo "${ADMIN_PASS}" | sudo -E -S bash ./packer/scripts/01-build-expand-volume.sh && \
	echo "${ADMIN_PASS}" | SSH_USERNAME="${SSH_USERNAME}" sudo -E -S bash ./packer/scripts/02-os-vars.sh
	make add-hosts-entry -- -f /etc/hosts -r ${DOMAIN} -a upsert
	echo "${ADMIN_PASS}" | SSH_USERNAME="${SSH_USERNAME}" sudo -E -S bash ./packer/scripts/02-os-configure.sh
	echo "${ADMIN_PASS}" | SSH_USERNAME="${SSH_USERNAME}" sudo -E -S bash ./packer/scripts/02-os-apps.sh
	make snapshot -- -n "BASE-CLUSTER-INSTALLED" -c 
	echo "${ADMIN_PASS}" | SSH_USERNAME="${SSH_USERNAME}" sudo -E -S bash ./packer/scripts/02-os-import-images.sh

add-coredns-hosts-entry:
	./scripts/add-coredns-hosts-entry.sh $(filter-out $@,$(MAKECMDGOALS))
%:
	@true

add-hosts-entry:
	echo "${ADMIN_PASS}" | sudo -E -S ./scripts/add-hosts-entry.sh $(filter-out $@,$(MAKECMDGOALS))
%:
	@true

init: sudo-deps
	SSH_USERNAME="${SSH_USERNAME}" ./packer/scripts/04-user-deps.sh
	make init-argo
	make snapshot
	
init-argo: 
	make add-coredns-hosts-entry -- -n kube-system -c coredns-custom -r ${DOMAIN} -a upsert
	make repo-sync
	./packer/scripts/03-argo-deps.sh
	make unseal-vault
	make vault-argo-role
	make vault-app-vars
	make gitea-init
	make repo-sync
	./packer/scripts/03-init-argo.sh
	
	
unseal-vault:
	./packer/scripts/09-unseal-vault.sh

vault-app-vars:
	./packer/scripts/08-vault-app-vars.sh

vault-reset-app-vars:
	rm -rf ./argocd/install/vault/kustomize/base/files/app-vars.yaml
	./packer/scripts/08-vault-app-vars.sh

vault-argo-role:
	./packer/scripts/08-vault-argo-args.sh
	
gitea-init:
	kubectl -n postgres exec appliance-postgresql-0 -- bash -c "PGPASSWORD=crucible psql -h localhost -p 5432 -U postgres -c 'create database gitea;'" || true 
	kubectl kustomize ./argocd/install/gitea/kustomize/overlays/appliance --enable-helm | kubectl apply -f - || true
	echo "sleep 10"; sleep 10
	kubectl -n gitea scale --replicas=0 deployment/appliance-gitea && echo "sleep 5"; sleep 5 && kubectl -n gitea scale --replicas=1 deployment/appliance-gitea
	./packer/scripts/05-setup-gitea.sh
	make download-packages
	# make gitea-init-repos
	# make gitea-replace-repos
	

gitea-init-repos:
	./packer/scripts/05-init-repos.sh ./argocd/install/gitea/kustomize/base/files/repos

gitea-replace-repos:
	./packer/scripts/05-replace-repos.sh ./argocd/install/gitea/kustomize/base/files/repos

gitea-reset:
	kubectl kustomize ./argocd/install/gitea/kustomize/overlays/appliance --enable-helm | kubectl delete -f - || true
	kubectl -n postgres exec appliance-postgresql-0 -- bash -c "PGPASSWORD=crucible psql -h localhost -p 5432 -U postgres -c 'DROP DATABASE gitea WITH (FORCE);'"

gitea-export-images:
	echo "${ADMIN_PASS}" | sudo -E -S ./packer/scripts/package-export-images.sh

gitea-import-images:
	echo "${ADMIN_PASS}" | sudo -E -S ./packer/scripts/10-import-images.sh

repo-sync:
	./packer/scripts/05-repo-sync.sh

download-packages:
	./packer/scripts/05-download-packages.sh ./argocd/install/gitea/kustomize/base/files/packages.yaml
%:
	@true

build:
	rm -rf ./packer/output && \
	rm -rf ./output && \
	rm -rf ./dist/output
	./packer/scripts/01-build-update-vars.sh ./appliance.yaml
	./packer/scripts/01-build-appliance.sh $(filter-out $@,$(MAKECMDGOALS)) -on-error=abort -force
%:
	@true

shrink:
	# make gitea-export-images
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
	@echo "${ADMIN_PASS}" | sudo -E -S ./packer/scripts/02-os-snapshot.sh $(filter-out $@,$(MAKECMDGOALS)) 
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
	kubectl create -f ./argocd/install/longhorn/kustomize/base/files/uninstall-longhorn.yaml || true
	sleep 60
	echo "${ADMIN_PASS}" | sudo -E -S k3s-uninstall.sh && sudo rm -rf /tmp/crucible-appliance || true
	sudo rm -rf /var/lib/longhorn
	sudo rm -rf /dev/longhorn
	rm -rf ./argocd/install/argocd/kustomize/base/files/argo-*-id
	rm -rf ./argocd/install/argocd/kustomize/appliance/files/argo-*-id
	rm -rf ./argocd/install/vault/kustomize/base/files/argo-*-id*
	rm -rf ./argocd/install/vault/kustomize/base/files/vault-keys*
	rm -rf ./argocd/install/argocd/kustomize/overlays/appliance/files/argo-role-id
	rm -rf ./argocd/install/argocd/kustomize/overlays/appliance/files/argo-secret-id
	
startup-logs:
	journalctl --unit crucible-appliance-startup

startup-tail-logs:
	journalctl --follow --unit crucible-appliance-startup
	
startup-update-script:
	sudo cp ./packer/scripts/crucible-appliance-startup.sh /usr/local/bin/crucible-appliance-startup.sh
	sudo chmod +x /usr/local/bin/crucible-appliance-startup.sh

startup-restart:
	echo "${ADMIN_PASS}" | sudo -E -S systemctl restart crucible-appliance-startup

tmp:
	echo "${ADMIN_PASS}" | sudo -E -S ./packer/scripts/tmp.sh

template:
	./packer/scripts/template.sh $(filter-out $@,$(MAKECMDGOALS))

.PHONY: all clean clean-certs init build argo offline-reset reset snapshot package-ova

all: init