#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#
# Crucible Appliance 02-os-vars.sh

# Get vars from appliamce.yaml
source <(yq '.vars | to_entries | .[] | (.key | upcase) + "=" + .value' ./appliance.yaml | xargs)

###############
#### VARS #####
###############
APPLIANCE_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
MIRRORS=$(cat <<EOF
mirrors:
  docker.io:
    endpoint:
      - https://mirror.gcr.io
  "*":
EOF
)
CRUCIBLE_VARS=$(cat <<EOF
#!/bin/bash 
export APPLIANCE_VERSION=
export APPLIANCE_IP=
export APPLIANCE_ENVIRONMENT=
export IS_ONLINE=
EOF
)
IS_ONLINE=$(curl -s --max-time 5 ifconfig.me >/dev/null && echo true || echo false)
echo "IS_ONLINE: $IS_ONLINE"
# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

# Get the appliance version
if git rev-parse --git-dir > /dev/null 2>&1; then
    VERSION_TAG=$(git tag --points-at HEAD)
    GIT_BRANCH=$(git branch --show-current)
    GIT_HASH=$(git rev-parse --short HEAD)
fi

if [ -n "$VERSION_TAG" ]; then
    BUILD_VERSION=$VERSION_TAG
elif [ -n "$GITHUB_PULL_REQUEST" ]; then
    BUILD_VERSION=PR$GITHUB_PULL_REQUEST-$GIT_HASH
elif [ -n "$GIT_HASH" ]; then
    BUILD_VERSION=${GIT_BRANCH:0:15}-$GIT_HASH
else
    BUILD_VERSION="custom-$(date '+%Y%m%d')"
fi

if [ -z $APPLIANCE_VERSION ]; then 
    APPLIANCE_VERSION="crucible-appliance-$BUILD_VERSION"
    echo "Setting APPLIANCE_VERSION to $APPLIANCE_VERSION in /etc/appliance_version"
    sudo echo "$APPLIANCE_VERSION" > /etc/appliance_version
else
    if [ $APPLIANCE_VERSION != crucible-appliance-$BUILD_VERSION ]; then 
        sudo echo "$APPLIANCE_VERSION" > /etc/appliance_version
        sudo sed -i "s/APPLIANCE_VERSION=/export APPLIANCE_VERSION=$APPLIANCE_VERSION/d" /etc/profile.d/crucible-env.sh
    fi
fi

# Set Up crucible-vars.sh
if [[ ! -f /etc/profile.d/crucible-env.sh ]]; then 
    sudo echo "$CRUCIBLE_VARS" > /etc/profile.d/crucible-env.sh
    sudo chmod a+rx /etc/profile.d/crucible-env.sh
fi
    echo "Setting APPLIANCE_VERSION to $APPLIANCE_VERSION in /etc/profile.d/crucible-env.sh"
    sudo sed -i "/APPLIANCE_VERSION=/c\export APPLIANCE_VERSION=\\$APPLIANCE_VERSION" /etc/profile.d/crucible-env.sh
    sudo sed -i "/APPLIANCE_IP=/c\export APPLIANCE_IP=\\$APPLIANCE_IP" /etc/profile.d/crucible-env.sh
    sudo sed -i "/APPLIANCE_ENVIRONMENT=APPLIANCE/c\export APPLIANCE_ENVIRONMENT=APPLIANCE" /etc/profile.d/crucible-env.sh
    sudo sed -i "/IS_ONLINE=/c\export IS_ONLINE=\\$IS_ONLINE" /etc/profile.d/crucible-env.sh



CURRENT_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
APPLIANCE_VERSION=${APPLIANCE_VERSION:-$(cat /etc/appliance_version)}
DOMAIN=${DOMAIN:-onprem.phl-imcite.net}

# Delete Ubuntu machine ID for proper DHCP operation on deploy
#echo -n > /etc/machine-id