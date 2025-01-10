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
    exec_command=$1
    echo "Executing '$exec_command'. Logs outputted to $2"
    temp_repodir="$(create_temp_repodir)"
    (cd "$temp_repodir" && $exec_command) > "$2"
    echo -e "\e[32mTest '$1' successful. Logs available: $2\e[0m"
}

execute_local_tests(){
    kubectl config use-context k3d-k3s-default
    project_names=("project" "project-other")
    pids=()
    for project_name in "${project_names[@]}"; do
        execute_test "$LAUNCH_PROJECT $project_name" "$(mktemp)" &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    echo -e "\e[32mTests succesful\e[0m"
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
