#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

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

execute_test(){
    echo "Executing '$1'. Logs outputted to $2"
    $1 > "$2"
    echo "Test '$1' succesful. Logs available: $2"
}

execute_local_tests(){
    kubectl config use-context k3d-k3s-default
    execute_test "$LAUNCH_PROJECT project" "$(mktemp)" &
    execute_test "$LAUNCH_PROJECT project-other" "$(mktemp)" &
    wait
    echo "Tests succesful."

}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi

if [ -d "$WORKSPACE_FOLDER/.git/rebase-merge" ] || [ -d "$WORKSPACE_FOLDER/.git/rebase-apply" ]; then
    echo "Rebase in progress. Skipping post-commit actions."
    exit 0
fi

output_information_and_sleep
clean_workspace
execute_local_tests
