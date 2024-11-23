#!/bin/bash -x

# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

GITEA_USERNAME="${ADMIN_USER:-administrator}"        # Replace with your Gitea username
GITEA_PASSWORD="${ADMIN_PASS:-crucible}"        # Replace with your Gitea password
GITEA_ORG="${GITEA_ORG:-crucible}"

# Gitea server details
GITEA_SERVER="https://${DOMAIN}/gitea"
GITEA_TARGET_BRANCH="main"

# Specify the base directory containing subdirectories
BASE_DIR="$($readlink_cmd $1)"
REPO_TMP=/tmp/appliance-repos
# reset tmp folder
rm -rf ${REPO_TMP}
mkdir -p ${REPO_TMP}

# Check if the base directory exists
if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: Directory $BASE_DIR does not exist."
    exit 1
fi

# Generate a random token name
TOKEN_NAME="repo-modify-$(date +%s)-$RANDOM"

# Request a token with the necessary scopes
echo "Generating API token..."
RESPONSE=$(curl -s -X POST "${GITEA_SERVER}/api/v1/users/${GITEA_USERNAME}/tokens" \
    -u "${GITEA_USERNAME}:${GITEA_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "'"${TOKEN_NAME}"'",
        "scopes": [
          "write:repository",
          "write:user",
          "write:organization"
        ]
    }')

# Extract the token value
GITEA_TOKEN=$(echo "$RESPONSE" | jq -r '.sha1')

if [[ -z "$GITEA_TOKEN" || "$GITEA_TOKEN" == "null" ]]; then
    echo "Error: Failed to generate API token. Response: $RESPONSE"
    exit 1
fi

echo "Token generated successfully: $TOKEN_NAME"

# Iterate over each subdirectory in the base directory
for DIR in "$BASE_DIR"/*; do
    if [[ -d "$DIR" ]]; then
        # Get the directory name
        BASENAME=$(basename "$DIR")
        REPO_NAME=${BASENAME%.*}
        
        echo "Processing directory: $DIR"
        
        # Check if the repository already exists
        REPO_CHECK=$(curl -s -X GET "${GITEA_SERVER}/api/v1/repos/${GITEA_ORG}/${REPO_NAME}" \
            -H "Authorization: token ${GITEA_TOKEN}")
        
        if echo "$REPO_CHECK" | jq -e '.id' >/dev/null 2>&1; then
            echo "Repository $REPO_NAME exists. cloning to ${REPO_TMP}"
            REPO_DEST="$($readlink_cmd ${REPO_TMP}/${REPO_NAME})"
            git clone ${GITEA_SERVER}/${GITEA_ORG}/${REPO_NAME} ${REPO_DEST} 
             # Directory to search for YAML files
            cd ${REPO_DEST}
            git checkout ${GITEA_TARGET_BRANCH}
            git config user.name "${GITEA_USERNAME}"
            git config user.email "${GITEA_USERNAME}@${DOMAIN}"
            git remote remove origin
            git remote add appliance "https://${GITEA_TOKEN}@${DOMAIN}/gitea/${GITEA_ORG}/${REPO_NAME}"
            
            # Loop through all YAML files in the directory
            # find . -type f -name "*.yaml" | while read -r file; do
            #     # Perform the replacement in each file
            #     echo "Updated $file"
            # done
            
            # git add --all
            # git commit -m "(automated) - updated vault paths"
            # git push origin main
        fi
        cd - >/dev/null
    fi
done