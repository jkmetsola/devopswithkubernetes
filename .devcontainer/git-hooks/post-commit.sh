#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
LAUNCH_PROJECT_TOOL=$WORKSPACE_FOLDER/tools/launch_project.sh

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

output_information_and_sleep(){
    git log -1
    echo ""
    echo "Commit succesful. Executing local tests after 10s."
    sleep 10
}

clean_workspace(){
    temp_env="$(mktemp)"
    cp "$WORKSPACE_FOLDER"/.env "$temp_env"
    output="$(git clean -f -X)"
    echo "$output" | grep -v "Removing .env" || true
    cp "$temp_env" "$WORKSPACE_FOLDER"/.env
}

execute_local_tests(){
    temp_logs="$(mktemp)"
    echo ""
    echo "Starting to execute local tests. Logs outputted to $temp_logs"
    {
        kubectl config use-context k3d-k3s-default
        $LAUNCH_PROJECT_TOOL project
        $LAUNCH_PROJECT_TOOL project-other
    } > "$temp_logs"
    echo "Tests succesful. Logs available: $temp_logs"
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi

output_information_and_sleep
clean_workspace
execute_local_tests
