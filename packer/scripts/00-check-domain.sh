#!/bin/bash
if [ -f ./appliance.yaml ]; then
  source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
else
    cat appliance.example.yaml | envsubst > appliance.yaml
    source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)
fi

if [ ${DOMAIN} != onprem.phl-imcite.net ]; then
    echo "Changing domain from onprem.phl-imcite.net to ${DOMAIN}"
    find . -type f -exec sed -i "s/onprem.phl-imcite.net/${DOMAIN}/g" {} \;
    echo "Changing legacy appliance domains"
    find . -type f -exec sed -i "s/onprem.phl-imcite.net/${DOMAIN}/g" {} \;
    find . -type f -exec sed -i "s/onprem.phl-imcite.net/${DOMAIN}/g" {} \;
    # commit the code
    git add --all
    git commit -m "Change domain from onprem.phl-imcite.net to ${DOMAIN}"    
fi