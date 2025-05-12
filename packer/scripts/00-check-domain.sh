#!/bin/bash
if [ -f ./appliance.yaml ]; then
  source ./packer/scripts/lib/functions.sh
  yaml_to_env "./appliance.yaml"
fi
    cat appliance.example.yaml | envsubst > appliance.yaml
    source ./packer/scripts/lib/functions.sh
    yaml_to_env "./appliance.yaml"
fi

if [ ${DOMAIN} != onprem.twn-imcite.net ]; then
    echo "Changing domain from onprem.twn-imcite.net to ${DOMAIN}"
    find . -path ./.git -prune -o -type f -exec sed -i "s/onprem.phl-imcite.net/${DOMAIN}/g" {} +
    find . -type f -exec sed -i "s/onprem.twn-imcite.net/${DOMAIN}/g" {} \;
    echo "Changing legacy appliance domains"
    find . -type f -exec sed -i "s/crucible.dev/${DOMAIN}/g" {} \;
    find . -type f -exec sed -i "s/foundry.local/${DOMAIN}/g" {} \;
    # commit the code
    git add --all
    git commit -m " to ${DOMAIN}"
fi