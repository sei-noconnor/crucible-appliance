#!/bin/bash
# 
# Copyright 2021 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.

#############################
#   Crucible Stack Install  #
#############################

# Change to the current directory
root_dir=/home/foundry
source $root_dir/scripts/utils
import_vars $root_dir/appliance-vars
export KUBECONFIG=$root_dir/.kube/config
export appliance_ip=$(ip route get 1 | awk '{print $(NF-2);exit}')
sed -i "/gitlab.foundry.local/c\\${appliance_ip} foundry.local gitlab.foundry.local" /etc/hosts
# export dns_server=${DNS_01:-8.8.8.8}
envsubst < coredns-configmap.yaml | kubectl apply -n kube-system -f -
kubectl rollout restart deployment/coredns -n kube-system