### Configure the Runnner
the start script will create a kind cluster and deploy a kubernetes self-hosted runner to the cluster. You can optionally run this in an existing cluster
```
export GITHUB_PERSONAL_TOKEN
make deploy-runner
```