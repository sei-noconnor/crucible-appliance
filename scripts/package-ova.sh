#!/bin/bash
DIST_DIR=./dist/ova
name=$1
ovf=`$(ls -1 $DIST_DIT/*.ovf)`
mf=`$(ls -1 $DIST_DIR/*.mf)`
vmdk=`$(ls -1 $DIST_DIR/*.vmdk)`
# Potential vbox to vmware fix
# sed 's;\(.*<vssd:VirtualSystemType>\).*\(</vssd:VirtualSystemType>\);\1${vmx-14}\2;;' -i nixos-20.09pre-git-x86_64-linux.ovf
# sum=$(sha1sum $ovf | cut -d ' ' -f-1)
# substituteInPlace $mf --replace "SHA1 ($ovf) = .*" "SHA1 ($ovf) = $sum"
echo "Writing OVA, this may take some time.
tar -cvf $DIST_DIR/$APPLIANCE_VERSION.ova $ovf $mf $vmdk
rm -rf $ova $mf $vmdk