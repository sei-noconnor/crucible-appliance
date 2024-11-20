#!/bin/bash -x

GITEA_USERNAME="${ADMIN_USER:-administrator}"        # Replace with your Gitea username
GITEA_PASSWORD="${ADMIN_PASS:-crucible}"        # Replace with your Gitea password
GITEA_ORG="${GITEA_ORG:-crucible}"

# Gitea server details
GITEA_SERVER="https://${GITEA_USERNAME}:${GITEA_PASSWORD}@${DOMAIN}/gitea"

# Specify the base directory containing subdirectories
BASE_DIR="$1"

# Check if the base directory exists
if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: Directory $BASE_DIR does not exist."
    exit 1
fi

# Generate a random token name
TOKEN_NAME="repo-mirror-$(date +%s)-$RANDOM"

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
        
        echo "Processing directory: $REPO_NAME"
        
        # Check if the repository already exists
        REPO_CHECK=$(curl -s -X GET "${GITEA_SERVER}/api/v1/repos/${GITEA_ORG}/${REPO_NAME}" \
            -H "Authorization: token ${GITEA_TOKEN}")
        
        if echo "$REPO_CHECK" | jq -e '.id' >/dev/null 2>&1; then
            echo "Repository $REPO_NAME already exists. Skipping creation."
        else
            # Create the repository in Gitea using the API
            RESPONSE=$(curl -s -X POST "${GITEA_SERVER}/api/v1/orgs/${GITEA_ORG}/repos" \
                -H "Authorization: token ${GITEA_TOKEN}" \
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
        REMOTE_URL="${GITEA_SERVER}/${GITEA_ORG}/${REPO_NAME}.git"
        git remote add appliance "${REMOTE_URL}" 2>/dev/null || git remote set-url appliance "${REMOTE_URL}"
        git config --unset remote.origin.mirror
        git config --bool core.bare false
        git checkout main
        git push appliance main
        git push appliance --mirror

        echo "Directory $REPO_NAME mirrored to Gitea successfully."
        cd - >/dev/null
    fi
done

echo "All directories processed."