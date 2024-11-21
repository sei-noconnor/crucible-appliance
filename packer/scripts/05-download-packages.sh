#!/bin/bash 
#export $(cat .env)
# Gitea details and YAML file path
YAML_FILE="$1"
DOMAIN="${DOMAIN:-localhost:3000}/gitea"
OWNER="${OWNER:-crucible}"
ADMIN_USER="${ADMIN_USER:-administrator}"
DIST_OUTPUT="${DIST_OUTPUT:-./dist}"
retry=""
CURL_OPTS=( --location --header "Content-Type: application/json" )
RANDOM_NAME=$(openssl rand -hex 4)
REQ=$(curl "${CURL_OPTS[@]}" \
  --user "${ADMIN_USER}:${ADMIN_PASS}" \
  --request POST "https://crucible.local/gitea/api/v1/users/$ADMIN_USER/tokens" \
  --data @- <<EOF
  {
    "name": "write-package-${RANDOM_NAME}",
    "scopes": [
      "write:package"
    ]
  }
EOF
)
ACCESS_TOKEN=$(echo ${REQ} | jq -r '.sha1')

# ACCESS_TOKEN=$( curl ${CURL_OPTS[@]} \
#                 --user ${ADMIN_USER}:${ADMIN_PASS} \
#                 -X POST "https://$DOMAIN/api/v1/users/$ADMIN_USER/tokens" \
#                 --data "{ \"name\": \"package-write\", \"scopes\": [ \"write:package\" ] }" 
# )
#CURL_OPTS="${CURL_OPTS[@]} --header Authorization: token ${ACCESS_TOKEN}"
# Function to process Helm packages
process_helm() {
  helm_output=${DIST_OUTPUT}/helm
  mkdir -p ${DIST_OUTPUT}/helm
  helm_count=$(yq eval ".helm | length" "$YAML_FILE")
  for i in $(seq 0 $(($helm_count - 1))); do
    repoName=$(yq eval ".helm[$i].name" "$YAML_FILE")
    repoUrl=$(yq eval ".helm[$i].repoUrl" "$YAML_FILE")
    giteaUrl=$(yq eval ".helm[$i].giteaUrl" "$YAML_FILE" | sed "s|\${DOMAIN}|$DOMAIN|g" | sed "s|\${OWNER}|$OWNER|g")
    helm repo add ${repoName} ${repoUrl} || true
    helm repo update
    # Iterate through helm items
    item_count=$(yq eval ".helm[$i].items | length" "$YAML_FILE")
    for j in $(seq 0 $(($item_count - 1))); do
      item=$(yq eval ".helm[$i].items[$j]" "$YAML_FILE")
      IFS=":" read -r name version <<< "$item"
      unset IFS
      if [ -n $version ]; then 
        helm pull "${repoName}/${name}" --version $version -d ${helm_output}
      else
        helm pull "${repoName}/${name}" -d ${helm_output}
      fi
      package_url=$(echo "$giteaUrl" | sed "s|\${OWNER}|$OWNER|g" | sed "s|\${DOMAIN}|$repoUrl|g")
      file=($(find "$helm_output" -type f -name "*$name*$version*" -print))
      echo "Uploading Helm chart $item to $package_url"
      curl --location --user ${ADMIN_USER}:${ADMIN_PASS} -X POST --upload-file $file $package_url
    done
  done
}

# Function to process container images
process_containers() {
  container_output=${DIST_OUTPUT}/container
  mkdir -p $container_output
  item_count=$(yq eval ".containers.items | length" "$YAML_FILE")
  for i in $(seq 0 $(($item_count - 1))); do
    item=$(yq eval ".containers.items[$i]" "$YAML_FILE")
    #Get the name everything from last '/' to end
    name="${item##*/}"
    # parse name and version
    IFS=":" read -r name version <<< "$name"
    unset IFS
    # check if the package already exists
    giteaUrl=$(yq eval ".containers.giteaUrl" "$YAML_FILE" | sed "s|\${DOMAIN}|$DOMAIN|g" | sed "s|\${OWNER}|$OWNER|g" | sed "s|\${ITEM}|$name|g" | sed "s|\${VERSION}|$version|g")
    resp=$(curl --silent --location --user ${ADMIN_USER}:${ADMIN_PASS} -X GET ${giteaUrl}) 
    message=$(echo $resp | jq -r '.message')
    if [ "$message" == "package does not exist" ]; then
      
      docker pull $item --platform=linux/amd64 || retry="$retry\n$item"
      image_tag=$(docker image inspect $item | jq -r '.[].RepoTags[0]')
      docker image tag $item $DOMAIN/$OWNER/$image_tag
      docker push $DOMAIN/$OWNER/$image_tag --platform=linux/amd64
    else
      echo "Package: $item exists, skipping"
    fi
    
  done
}

# Function to process Debian packages
process_debian() {
  debian_output="$DIST_OUTPUT/debian"
  mkdir -p $debian_output
  debian_count=$(yq eval ".debian | length" "$YAML_FILE")
  for i in $(seq 0 $(($debian_count - 1))); do
    distro=$(yq eval ".debian[$i].distro" "$YAML_FILE")
    os=$(yq eval ".debian[$i].os" "$YAML_FILE")
    version=$(yq eval ".debian[$i].version" "$YAML_FILE")
    giteaUrl=$(yq eval ".debian[$i].giteaUrl" "$YAML_FILE" | sed "s|\${DOMAIN}|$DOMAIN|g" | sed "s|\${OWNER}|$OWNER|g" | sed "s|\${DISTRO}|$distro|g")
    debian_output="$debian_output/$distro"
    mkdir -p $debian_output
    items=""
    # Iterate through debian items
    item_count=$(yq eval ".debian[$i].items | length" "$YAML_FILE")
    for j in $(seq 0 $(($item_count - 1))); do
      item=$(yq eval ".debian[$i].items[$j]" "$YAML_FILE")
      items="$items $item"
    done
    docker run --platform="linux/amd64" --rm -v $debian_output:/var/cache/apt/archives $os:$version bash -c "apt-get update && apt-get --download-only install -y $items"
    for file in $debian_output/*; do
      if [ -f "$file" ]; then 
        curl --location --user $ADMIN_USER:$ADMIN_PASS -X PUT --upload-file $file $giteaUrl
        echo "Uploaded file $file"
      fi
    done
  done
}

# Function to process Generic files
process_generic() {
  generic_output="$DIST_OUTPUT/generic"
  mkdir -p $generic_output
  generic_count=$(yq eval ".generic | length" "$YAML_FILE")
  for i in $(seq 0 $(($generic_count - 1))); do
    giteaUrl=$(yq eval ".generic[$i].giteaUrl" "$YAML_FILE" | sed "s|\${DOMAIN}|$DOMAIN|g" | sed "s|\${OWNER}|$OWNER|g")
    item_count=$(yq eval ".generic[$i].items | length" "$YAML_FILE")

    for j in $(seq 0 $(($item_count - 1))); do
      item=$(yq eval ".generic[$i].items[$j]" "$YAML_FILE")
      file_name=$(basename "$item")
      file_version="0.0.0"  # Example, adjust as needed
      if [ -f $generic_output/$file_name ]; then
        echo "Checking file size"
      else
        curl -L -o $generic_output/$file_name $item 
      fi
      package_url=$(echo "$giteaUrl" | sed "s|\${FILE}|$file_name|g" | sed "s|\${FILE_VERSION}|$file_version|g" | sed "s|\${FILE_NAME}|$file_name|g")
      echo "Uploading generic file $item to $package_url"
      curl --location -X PUT --upload-file $generic_output/$file_name $package_url?access_token=${ACCESS_TOKEN}
    done
  done
}

# Main script
# echo "Processing Helm charts..."
# process_helm

# echo "Processing Debian packages..."
# process_debian

echo "Processing generic files..."
process_generic

# echo "Processing containers..."
# process_containers