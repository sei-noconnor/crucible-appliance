#!/bin/bash
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