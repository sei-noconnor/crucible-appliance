## Installation 
Installation is done with a packer build which consists of 4 phases 

- building the os
    - Install the os with packer
        - `make build`

- configuring the os
    - Configure the os with dependencies
        - `make init`
    
- bootstrap the cluster
    - create certificates
        - `make generate_certs`
    - deploy cert-manager
        - `make init-argo` 
    - deploy nginx ingress
        - `make init-argo`
    - deploy longhorn storage
        - `make init-argo`
    - deploy and provision postgres
        - `make init-argo`
    - deploy and provision vault
        - `make init-argo`
    - deploy argo cd 
        - `make init-argo`

- provision the cluster
    - deploy root-app for crucible apps.