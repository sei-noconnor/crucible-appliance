#!/bin/bash -x
# Detect Mac and use greadlink
readlink_cmd="readlink -m"
if [[ "$OSTYPE" == "darwin"* ]]; then
  readlink_cmd="greadlink -m"  
fi

## Variables
# The Source server variables specify the URLs and repos to clone into the appliance 
# Source server
GITEA_SOURCE_SERVER="fortress.sei.cmu.edu/gitea"
GITEA_SOURCE_USERNAME=${GITEA_SOURCE_USERNAME:-administrator}
GITEA_SOURCE_PASSWORD=${GITEA_SOURCE_PASSWORD:-}
GITEA_SOURCE_ORG=${GITEA_SOURCE_ORG:-fortress-manifests}

# The Destination server variables are essentially pre-defined. We use the DOMAIN 
# environment variable to construct the URLs.
# Duplicate repos will be overwritten with last in array
# Destination server
GITEA_DEST_SERVER="${DOMAIN}/gitea"
GITEA_DEST_USERNAME=${GITEA_DEST_USERNAME:-administrator}
GITEA_DEST_PASSWORD=${GITEA_DEST_PASSWORD:-crucible}
GITEA_DEST_ORG=${GITEA_DEST_ORG:-fortress-manifests}

# Local vars
LOCAL_REPO_DIR=/home/$USER/repos

# Check for source repo admin password.
# if [[ -z "${GITEA_SOURCE_PASSWORD}" || "${GITEA_SOURCE_PASSWORD}" == "null" ]]; then 
#     read -sp "Enter the password for ${GITEA_SOURCE_SERVER}:  " USER_INPUT
#     echo
#     if [ -z "$USER_INPUT" ]; then
#         echo "Password cannot be empty. Exiting."
#         exit 1
#     fi
#     # Set the environment variable
#     export GITEA_SOURCE_PASSWORD="$USER_INPUT"
# fi

echo "Processing repos in ${LOCAL_REPO_DIR}"

# Check if the base directory exists
if [[ ! -d "${LOCAL_REPO_DIR}" ]]; then
    echo "Error: Directory ${LOCAL_REPO_DIR} does not exist. Creating."
    mkdir -p ${LOCAL_REPO_DIR}
fi

function get_token() {
    local SERVER=$1
    local USERNAME=$2
    local PASSWORD=$3
    local SCOPES=$4
    # Generate a random token name
    local TOKEN_NAME="repo-mirror-$(date +%s)-$RANDOM"

    # Request a token with the necessary scopes
    RESPONSE=$(curl -s -X POST "https://${SERVER}/api/v1/users/${USERNAME}/tokens" \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "'"${TOKEN_NAME}"'",
            "scopes": ["'"${SCOPES}"'"]
        }')

    # Extract the token value
    TOKEN=$(echo "$RESPONSE" | jq -r '.sha1')
    if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
        echo "Error: Failed to generate API token. Response: $RESPONSE"
        exit 1
    fi

    #echo "Token generated successfully: $TOKEN_NAME from ${SERVER}"
    echo $TOKEN
}
#GITEA_SOURCE_TOKEN=$(get_token "${GITEA_SOURCE_SERVER}" "${GITEA_SOURCE_USERNAME}" "${GITEA_SOURCE_PASSWORD}" "repo,write:org")
GITEA_DEST_TOKEN=$(get_token "${GITEA_DEST_SERVER}" "${GITEA_DEST_USERNAME}" "${GITEA_DEST_PASSWORD}" "write:organization,write:package,write:repository")

# # You could also specify arbitrary repos anywhere 
# GITEA_SOURCE_REPOS=(
#     "https://${GITEA_SOURCE_TOKEN}@${GITEA_SOURCE_SERVER}/${GITEA_SOURCE_ORG}/fortress-prod-argo.git"
#     "https://${GITEA_SOURCE_TOKEN}@${GITEA_SOURCE_SERVER}/${GITEA_SOURCE_ORG}/fortress-prod-k8s.git"
# )
# #Download the source repos
# for repo in "${GITEA_SOURCE_REPOS[@]}"; do
#     echo "Downloading repo $repo"
#     BASENAME=$(basename "$repo")
#     REPO_NAME=${BASENAME%.*}
#     git clone $repo --bare ${LOCAL_REPO_DIR}/${REPO_NAME}
# done

# Iterate over each subdirectory in the base directory and load to appliance gitea server
for DIR in "${LOCAL_REPO_DIR}"/*; do
    if [[ -d "$DIR" ]]; then
        # Get the directory name
        BASENAME=$(basename "$DIR")
        REPO_NAME=${BASENAME%.*}
        
        echo "Processing directory: $DIR"
        
        # Check if the repository already exists
        REPO_CHECK=$(curl -s -X GET "https://${GITEA_DEST_SERVER}/api/v1/repos/${GITEA_DEST_ORG}/${REPO_NAME}" \
            -H "Authorization: token ${GITEA_DEST_TOKEN}")
        
        if echo "$REPO_CHECK" | jq -e '.id' >/dev/null 2>&1; then
            echo "Repository $REPO_NAME already exists. Skipping creation."
        else
            # Create the repository in Gitea using the API
            RESPONSE=$(curl -s -X POST "https://${GITEA_DEST_SERVER}/api/v1/orgs/${GITEA_DEST_ORG}/repos" \
                -H "Authorization: token ${GITEA_DEST_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '{
                    "name": "'"${REPO_NAME}"'",
                    "private": false,
                    "description": "Mirror of '"${REPO_NAME}"'",
                    "auto_init": false
                }')
            
            if echo "$RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
                echo "Repository $REPO_NAME created successfully."
            else
                echo "Failed to create repository for $REPO_NAME. Response: $RESPONSE"
                continue
            fi
        fi

        # Clone, initialize Git repo, and push to Gitea
        cd "$DIR"
        
        # Set the remote and push
        # git config --local --bool core.bare false 
        # git reset HEAD -- .
        REMOTE_URL="https://${GITEA_DEST_TOKEN}@${GITEA_DEST_SERVER}/${GITEA_DEST_ORG}/${REPO_NAME}.git"
        git remote add appliance "${REMOTE_URL}" 2>/dev/null || git remote set-url appliance "${REMOTE_URL}"
        git push -u appliance main
        git push -u appliance --all

        echo "Directory $REPO_NAME mirrored to Gitea successfully."
        cd - >/dev/null
    fi
done
echo "All directories processed."