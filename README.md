Crucible Appliance - Argo
This is a reop to provision a Crucible appliance by way of argocd manifest and git repositories. 

1. install vault.
1. install ingress
1. install Argo Manifest
1. enable vault plugin. 

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





