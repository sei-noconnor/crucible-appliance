#!/bin/bash
# VARS
PACKER_DIR=TOOLS_DIR="/Users/noconnor/source/crucible/Crucible.Appliance.Argo/packer"
TOOLS_DIR="/Users/noconnor/source/crucible/Crucible.Appliance.Argo/packer/tools"
MIN_SIZE=15000000
#TOOLS_DIR=$(readlink -f $0)


# Detect OS

# Install ofvtool 
mkdir -p $TOOLS_DIR
if [ ! -f $TOOLS_DIR/ovftool.zip ]; then
# Check size
fsize=$(wc -c < $TOOLS_DIR/ovftool.zip)
    if [ $fsize -lt $MIN_SIZE]; then
        curl "https://dp-downloads.broadcom.com/?file=VMware-ovftool-4.6.3-24031167-mac.x64.zip&oid=42683&id=-WfYECNaDyvzW0arfHYHouKPwh76pq4Mwk0zXz1GwS9PZQK1F2mw9cbn1PYtDqs=&specDownload=true&verify=1721402702-BH0cf%2BIWzvTq6b3zbvUSULmELNv%2BDezMs0AHE3ivz7s%3D" --output "$TOOLS_DIR/ovftool.zip"
    else
        echo "OVF Zip exists and file size $fsize"
    fi
fi
ls $TOOLS_DIR
unzip "$TOOLS_DIR/ovftool.zip" -d "$TOOLS_DIR/tmp/"
sleep 5
rsync -a $TOOLS_DIR/tmp/VMWare\ OVF\ TOOL\/ $TOOLS_DIR/ofvtool
#export PATH="$PATH:$TOOLS_DIR/ovftool"
rm -rf $TOOLS_DIR/tmp