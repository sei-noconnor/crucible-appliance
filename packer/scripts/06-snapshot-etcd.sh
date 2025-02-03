#!/bin/bash

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi
prefix="${1:-crucible-appliance}"

sudo k3s etcd-snapshot save --snapshot-compress -name $prefix