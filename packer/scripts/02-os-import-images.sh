#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#

# Get vars from appliamce.yaml
source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)

DIST_DIR=./dist
# limit docker pulls if container images exist
if [ -f $DIST_DIR/containers/images-amd64.tar.zst ]; then 
    make gitea-import-images
fi