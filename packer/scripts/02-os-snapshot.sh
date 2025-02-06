#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#

# Get vars from appliamce.yaml
source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)

# Take base cluster snapshot
echo "Sleeping for 20 seconds for snapshot"
sleep 20
k3s etcd-snapshot save --snapshot-compress --name base-cluster
