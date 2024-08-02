#!/bin/bash
# Create a folder
mkdir actions-runner && cd actions-runner 
# Download the latest runner package
curl -o actions-runner-linux-x64-2.317.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz
# Optional: Validate the hash
echo "9e883d210df8c6028aff475475a457d380353f9d01877d51cc01a17b2a91161d  actions-runner-linux-x64-2.317.0.tar.gz" | shasum -a 256 -c
# Extract the installer
mkdir -p /tmp/gha-runner && tar xzf ./actions-runner-linux-x64-2.317.0.tar.gz -C /tmp/gha-runner
cd /tmp/gha-runner
./config.sh --url https://github.com/NicCOConnor/crucible-appliance-argo --token ABHJCAPBUTS7VMW3GXMFHGLGVTTZM
./run.sh 