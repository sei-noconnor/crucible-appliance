#!/bin/bash

# Vars
CONTEXT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Default values
RUNNER_IMAGE="crucible.io/fortress-manifests/gitea-runner:crucible"
RUNNER_TOKEN=""
RUNNER_NAME="crucible-gitea-runner"
RUNNER_INSTANCE_URL="https://crucible.io/gitea"
RUNNER_CONFIG_FILE="config.yaml"
RUNNER_STOP=false
RUNNER_DELETE=false
RUNNER_BUILD=false
RUNNER_BUILD_ONLY=false
CONTAINER_BINARY=$(which docker || which podman)

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -r, --runner-image      Runner image (default: $RUNNER_IMAGE)"
    echo "  -t, --token             Runner token for git server"
    echo "  -i, --instance-url      Git server instance URL (default: $RUNNER_INSTANCE_URL)"
    echo "  -n, --instance-name     Name of the runner instance (default: $RUNNER_NAME)"
    echo "  -c, --config-file       Config file name (default: $RUNNER_CONFIG_FILE)"
    echo "  -b, --build             Force build image"
    echo "      --build-only        Exit after building"
    echo "  -d, --delete            Delete local container image"
    echo "  -s, --stop              Stop the runner"
    echo "  -h, --help              Display this help message"
    exit 0
}

# Parse arguments with `getopt`
OPTIONS=$(getopt -o r:t:i:n:c:bsd:h --long runner-image:,token:,instance-url:,instance-name:,config-file:,build,build-only,delete,stop,help -n "$0" -- "$@")
if [ $? -ne 0 ]; then
    usage
fi

eval set -- "$OPTIONS"

# Parse options
while true; do
    case "$1" in
        -r|--runner-image) RUNNER_IMAGE="$2"; shift 2 ;;
        -t|--token) RUNNER_TOKEN="$2"; shift 2 ;;
        -i|--instance-url) RUNNER_INSTANCE_URL="$2"; shift 2 ;;
        -n|--instance-name) RUNNER_NAME="$2"; shift 2 ;;
        -c|--config-file) RUNNER_CONFIG_FILE="$2"; shift 2 ;;
        -b|--build) RUNNER_BUILD=true; shift ;;
        --build-only) RUNNER_BUILD_ONLY=true; shift ;;
        -d|--delete) RUNNER_DELETE=true; shift ;;
        -s|--stop) RUNNER_STOP=true; shift ;;
        -h|--help) usage; shift ;;
        --) shift; break ;;
        *) echo "Invalid option: $1"; usage ;;
    esac
done

# Output parsed options for debugging
echo
echo ""
echo "Script Options Set"
echo "------------------------------------"
echo ""
echo "Runner Image: $RUNNER_IMAGE"
echo "Token: $RUNNER_TOKEN"
echo "Instance URL: $RUNNER_INSTANCE_URL"
echo "Runner Name: $RUNNER_NAME"
echo "Config File: $RUNNER_CONFIG_FILE"
echo "Build: $RUNNER_BUILD"
echo "Build Only: $RUNNER_BUILD_ONLY"
echo "Stop: $RUNNER_STOP"
echo "Delete: $RUNNER_DELETE"
echo ""
echo ""


# Delete runner if flag is set
if [[ "$RUNNER_DELETE" = true ]]; then
    echo "Delete runner flag set, Deleting runner"
    ID=$($CONTAINER_BINARY ps -a | grep $RUNNER_NAME | awk '{print $1}')
    if [ -n "$ID" ]; then 
        echo "Stopping runner $RUNNER_NAME with id: $ID"
        $CONTAINER_BINARY rm -f $ID
        echo "Runner stopped"
    else
        echo "Runner doesn't exists, exiting"
    fi
    exit 0
fi

# Build the runner if flag is set
if [[ "$RUNNER_BUILD" = true ]]; then
    $CONTAINER_BINARY buildx build --progress=plain --platform=linux/amd64 $CONTEXT_DIR/. -t $RUNNER_IMAGE
    if [[ "$RUNNER_BUILD_ONLY" = true ]]; then
        exit 0
    fi
fi

# Check if the Runner token is set 
if [ -n "$RUNNER_TOKEN" ]; then
    echo "RUNNER_TOKEN is set"
else
    echo "RUNNER_TOKEN is not set. Please set the token"
    usage
    exit 2
fi

# Generate a config file if it doesn't exist
if [ ! -f "$CONTEXT_DIR/$RUNNER_CONFIG_FILE" ]; then 
    DIR=$PWD
    cd $CONTEXT_DIR
    echo "Runner config file does not exist, generating"
    $CONTAINER_BINARY run \
        --entrypoint="" --rm -it $RUNNER_IMAGE \
        act_runner generate-config > $RUNNER_CONFIG_FILE
    echo "Runner config file created"
    cd $DIR
fi

# Run the container locally for testing
if [ -n "$CONTAINER_BINARY" ]; then
    $CONTAINER_BINARY run \
    --name $RUNNER_NAME \
    -e GITEA_INSTANCE_URL="$RUNNER_INSTANCE_URL" \
    -e GITEA_RUNNER_REGISTRATION_TOKEN="$RUNNER_TOKEN" \
    $RUNNER_IMAGE
else
    echo "Can't find container binary (docker or podman), please install"
fi

