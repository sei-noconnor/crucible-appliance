## Application Access & Credentials

| Application | URL                                                                      | API URL                                                                    | Default Username | Default Password |
| ----------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------- | ---------------- | ---------------- |
| Player      | [https://player.$DOMAIN](https://player.$DOMAIN)                 | [https://player.$DOMAIN/api](https://player.$DOMAIN/api)           | administrator    | crucible         |
| Alloy       | [https://alloy.$DOMAIN](https://alloy.$DOMAIN)                   | [https://player.$DOMAIN/api](https://player.$DOMAIN/api)           | administrator    | crucible         |
| Caster      | [https://caster.$DOMAIN](https://caster.$DOMAIN)                 | [https://caster.$DOMAIN/api](https://caster.$DOMAIN/api)           | administrator    | crucible         |
| Steamfitter | [https://steamfitter.$DOMAIN](https://steamfitter.$DOMAIN)       | [https://steamfitter.$DOMAIN/api](https://steamfitter.$DOMAIN/api) | admin            | crucible         |
| Gameboard   | [https://gameboard.$DOMAIN](https://gameboard.$DOMAIN)           | [https://gameboard.$DOMAIN/api](https://gameboard.$DOMAIN/api)     | admin            | crucible         |
| TopoMojo    | [https://topomojo.$DOMAIN](https://topomojo.$DOMAIN)             | [https://topomojo.$DOMAIN/api](https://topomojo.$DOMAIN/api)       | admin            | crucible         |
| Gitea       | [https://gitea.$DOMAIN](https://gitea.$DOMAIN)                   | [https://gitea.$DOMAIN/api](https://gitea.$DOMAIN/api)             | giteaadmin       | crucible         |
| ArgoCD      | [https://cd.$DOMAIN](https://cd.$DOMAIN)                         | -                                                                          | admin            | crucible         |
| Keycloak    | [https://$DOMAIN/keycloak/admin](https://$DOMAIN/keycloak/admin) | -                                                                          | admin            | crucible         |
| Vault       | [https://keystore.$DOMAIN](https://keystore.$DOMAIN)             | -                                                                          | root\_key        | crucible         |
| Postgres    | Internal only                                                            | -                                                                          | postgres         | crucible         |
| Stackstorm  | [https://stackstorm.$DOMAIN](https://stackstorm.$DOMAIN)         | -                                                                          | user             | crucible         |
| MISP        | [https://misp.$DOMAIN](https://misp.$DOMAIN)                     | -                                                                          | user             | crucible         |
| Moodle      | [https://moodle.$DOMAIN](https://moodle.$DOMAIN)                 | -                                                                          | user             | crucible         |
| OSTicket    | [https://osticket.$DOMAIN](https://osticket.$DOMAIN)             | -                                                                          | user             | crucible         |

> ⚠️ Default credentials should be changed after the first login.
> ✅ URLs assume DNS is properly configured to resolve `*.$DOMAIN`.