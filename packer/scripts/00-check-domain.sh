#!/bin/bash
if ! command -v yq &> /dev/null; then
    echo "yq not found, installing..."
    YQ_VERSION="v4.34.1" # Replace with the desired version
    wget "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -O /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
fi
if [ -f ./appliance.yaml ]; then
  source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
else
    cat appliance.example.yaml | envsubst > appliance.yaml
    source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
fi

if [ ${DOMAIN} != onprem.phl-imcite.net ]; then
    echo "Changing domain from crucible.io to ${DOMAIN}"
    find . -type f -exec sed -i "s/crucible.io/${DOMAIN}/g" {} \;
    echo "Changing legacy appliance domains"
    find . -type f -exec sed -i "s/crucible.dev/${DOMAIN}/g" {} \;
    find . -type f -exec sed -i "s/foundry.local/${DOMAIN}/g" {} \;
    # commit the code
    git add --all
    git commit -m " to ${DOMAIN}"    
fi