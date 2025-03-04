#!/bin/bash
if [ -f ./appliance.yaml ]; then
  source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
else
    cat appliance.example.yaml | envsubst > appliance.yaml
    source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
fi

if [ ${DOMAIN} != crucible.io ]; then
    echo "Changing domain from crucible.io to ${DOMAIN}"
    find . -type f -exec sed -i "s/crucible.io/${DOMAIN}/g" {} \;
    # commit the code
    git add --all
    git commit -m "Change domain from crucible.io to ${DOMAIN}"    
fi