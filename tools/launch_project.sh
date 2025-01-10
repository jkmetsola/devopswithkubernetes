#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_ARG="$1"
DEPLOY_APPS_TOOL=$WORKSPACE_FOLDER/tools/launch-project-utils/deploy-apps.sh
DEPLOY_JOBS_TOOL=$WORKSPACE_FOLDER/tools/launch-project-utils/deploy-cronjobs.sh

echo_errors_on_exit1() {
    if [ "$?" -eq 1 ]; then
        echo "Script '$SCRIPT_NAME $SCRIPT_ARG' exited with code 1." >&2
        echo "Error logs available $ERROR_LOG" >&2
        echo "workspace folder: $WORKSPACE_FOLDER" >&2
        for pid in "${APP_TYPE_PIDS[@]}"; do
            kill "$pid" 2>/dev/null || true
        done
        exit 1
    fi
}

launch_projects() {
    EXECUTION_PIDS=()
    if [[ "${1:-}" == "$(basename "${PROJECT_FOLDER}")" ]]; then
        commands=(
            "$DEPLOY_APPS_TOOL ${PROJECT_COMMON_FOLDER}/databases"
            "$DEPLOY_JOBS_TOOL ${PROJECT_FOLDER}/jobs"
            "$DEPLOY_APPS_TOOL ${PROJECT_FOLDER}/apps"
        )
    elif [[ "${1:-}" == "$(basename "${PROJECT_OTHER_FOLDER}")" ]]; then
        commands=(
            "$DEPLOY_APPS_TOOL ${PROJECT_COMMON_FOLDER}/databases"
            "$DEPLOY_APPS_TOOL ${PROJECT_OTHER_FOLDER}/apps"
        )
    fi
    for cmd in "${commands[@]}"; do
        $cmd "$NAMESPACE" &
        EXECUTION_PIDS+=($!)
    done
    for execution_pid in "${EXECUTION_PIDS[@]}"; do
        wait "$execution_pid"
    done
    kubectl cluster-info
    kubectl get --namespace "$NAMESPACE" svc,ing
}

main() {
    if [[ -n "${DEBUG:-}" ]]; then
        set -x
        export DEBUG
    fi
    trap echo_errors_on_exit1 EXIT
    NAMESPACE="$("$APPLY_NAMESPACE_TOOL" "$1" "$VERSION_BRANCH" "$ERROR_LOG")"
    kubectl delete all --all -n "$NAMESPACE"
    launch_projects "$1"
}

main "$1"
