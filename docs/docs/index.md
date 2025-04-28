# Crucible

Welcome to the **Crucible Appliance**. This virtual machine hosts workforce development apps from the [Software Engineering Institute](https://sei.cmu.edu) at [Carnegie Mellon University](https://cmu.edu).

## Getting started

The appliance uses the _crucible.io_ domain, you'll need to place an entry in your DNS server or HOSTS file to access the appliance.

To get started using the virtual appliance:

1. Download [root-ca.pem](root-ca.pem) and trust it in your keychain/certificate store. This removes browser certificate warnings.
2. Navigate to any of the apps in the following two sections.
3. Unless otherwise noted, the default credentials are:

   | key      | value                       |
   | -------- | --------------------------- |
   | username | `administrator@crucible.io` |
   | password | `${ADMIN_PASS}`             |

## Crucible apps

The following Crucible applications are loaded on this appliance:

| location                                       | api                                        | description                                                                                                                                                      |
| ---------------------------------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [player](https://player.crucible.io)          | [api](https://player.crucibhle.io/api)     | _Player_ is the centralized interface where users, teams, and administrators go to participate in the cyber exercise.                                            |
| [alloy](https://alloy.crucible.io)             | [api](https://player.crucible.io/api)      | _Alloy_ joins the other independent Crucible apps together to provide a complete Crucible experience (i.e. labs, on-demand exercises, exercises, etc.).          |
| [caster](https://caster.crucible.io)           | [api](https://caster.crucibl.io/api)       | _Caster_ provides a web interface that gives exercise developers a way to create, share, and manage topology configurations.                                     |
| [steamfitter](https://steamfitter.crucible.io) | [api](https://steamfitter.crucible.io/api) | _Steamfitter_ creates scenarios consisting of a series of scheduled tasks, manual tasks, and injects which run against virtual machines in an exercise.delivery. |

## Third-party apps

The following third-party applications are loaded on this appliance:

| location                                                          | description                                  |
| ----------------------------------------------------------------- | -------------------------------------------- |
| [gitea](https://crucibhle.io/gitea) | _stackstorm_ Task processing for steamfitter |
| [stackstorm](https://crucibhle.io/stackstorm) | _stackstorm_ Task processing for steamfitter |

![CMU SEI Unitmark](assets/cmu-sei-unitmark.png){: style="width:400px;margin:40px 0px 0px"}
