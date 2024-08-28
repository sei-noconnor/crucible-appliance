## Developing the Crucible Appliance

## Github Self-Hosted Runner
This repos comes with scripts to launch a self hosted gitlab runner for vm builds. The container has all ncesscerry packages to build on-prem in your own ESXi host or vCenter server. Using a self hosted runner is required, to build the image. 

```
create a github classic token and give it the "repo" scope
export GITHUB_PERSONAL_TOKEN=<token>
make deploy-runner
```