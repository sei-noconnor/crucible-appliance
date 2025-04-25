# Foundry Appliance {version}

Welcome to the **Foundry Appliance**. This virtual machine hosts workforce development apps from the [Software Engineering Institute](https://sei.cmu.edu) at [Carnegie Mellon University](https://cmu.edu).

## Getting started

The appliance advertises the _crucible.io_ domain via mDNS. All apps are served as subdirectories under this domain.

To get started using the virtual appliance:

1. Download [root-ca.crt](root-ca.crt) and trust it in your keychain/certificate store. This removes browser certificate warnings.
2. Navigate to any of the apps in the following two sections.
3. Unless otherwise noted, the default credentials are:

   | key      | value                         |
   | -------- | ----------------------------- |
   | username | `administrator@crucible.io` |
   | password | `${ADMIN_PASS}`                     |
   

## Common apps

The following Foundry applications are loaded on this appliance:

| location               | api                  | description                                                                                                      |
| ---------------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------- |
| TODO: Document Common Apps | | |

## Third-party apps

The following third-party applications are loaded on this appliance:

| location                 | description                                                                                                             |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| [/gitea](/gitea)         | _Gitea_ provides a user interface for editing the web content on the appliance (including this page).                   |

## Under the hood

For command line access to the appliance:

```
ssh crucible@crucible.io
```

The SSH password is `${ADMIN_PASS}$`. Then you can run normal Kubernetes commands via `kubectl`.

```
kubectl get pods
```

The code for building this virtual machine is [available on GitHub](https://github.com/cmu-sei/gameboard-appliance)

The appliance runs all of the apps in a single-host Kubernetes cluster provided by [K3s](https://k3s.io/). This provides a starting point for production-ready deployments in a datacenter or cloud.

![CMU SEI Unitmark](assets/cmu-sei-unitmark.png){: style="width:400px;margin:40px 0px 0px"}
