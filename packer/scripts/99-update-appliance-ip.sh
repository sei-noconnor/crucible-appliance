#!/bin/bash
# 
# Copyright 2021 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.

#################################
# Crucible Appliance IP Cronjob #
#################################

###############
#### VARS #####
###############
DOMAIN=$1
shift
ARGS=$*
# Change to the current directory
DIR=$(dirname ${BASH_SOURCE[0]})
cd "$DIR"
SCRIPTS_DIR=${PWD}

# Change to the current directory
root_dir="/home/$SSH_USERNAME"


export KUBECONFIG=$root_dir/.kube/config
export appliance_ip=$(ip route get 1 | awk '{print $(NF-2);exit}')
sed -i "/gitlab.$DOMAIN/c\\${appliance_ip} $DOMAIN gitlab.$DOMAIN" /etc/hosts
# export dns_server=${DNS_01:-8.8.8.8}
envsubst < coredns-configmap.yaml | kubectl apply -n kube-system -f -
kubectl rollout restart deployment/coredns -n kube-system