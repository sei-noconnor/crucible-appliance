#!/bin/sh

instance_url="${INSTANCE_URL:-https://crucible.io/gitea}"
token=${RUNNER_TOKEN}
echo "Registering act_runner at URL '${instance_url}'"
/actions-runner/action_runner register --no-interactive --instance $instance_url --token $token 


remove() {
    ./config.sh remove --unattended --token "${RUNNER_TOKEN}"
}

trap 'remove; exit 130' INT
trap 'remove; exit 143' TERM