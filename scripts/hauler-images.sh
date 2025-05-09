#!/bin/bash 
# fetch all images in the cluster, remove duplicates, alphabetize, and put on a newline
export IMAGE_LIST=$(kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" | sed 's/ /\n/g' | sort | uniq)
export IMAGE_LIST_MODIFIED=$(echo "${IMAGE_LIST}" | sed 's/^/    - name: /')
STORE_DIR=./dist/store
mkdir -p $STORE_DIR
# create the hauler manifest with the updated image list
cat << EOF > ./dist/store/hauler-manifest.yaml
apiVersion: content.hauler.cattle.io/v1
kind: Images
metadata:
  name: hauler-cluster-images
spec:
  images:
$IMAGE_LIST_MODIFIED
EOF
hauler store sync -s $STORE_DIR --files=$STORE_DIR/hauler-manifest.yaml 
