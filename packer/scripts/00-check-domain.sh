#!/bin/bash
if [ -f ./appliance.yaml ]; then
  source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
else
    cat appliance.example.yaml | envsubst > appliance.yaml
    source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
fi

if [ ${DOMAIN} != onprem.imcite-phl.net ]; then
    echo "Changing domain from onprem.imcite-phl.net to ${DOMAIN}"
    find . -type f -exec sed -i "s/onprem.imcite-phl.net/${DOMAIN}/g" {} \;
    echo "Changing legacy appliance domains"
    find . -type f -exec sed -i "s/onprem.imcite-phl.net/${DOMAIN}/g" {} \;
    find . -type f -exec sed -i "s/onprem.imcite-phl.net/${DOMAIN}/g" {} \;
    # commit the code
    git add --all
    git commit -m "Change domain from onprem.imcite-phl.net to ${DOMAIN}"    
fi