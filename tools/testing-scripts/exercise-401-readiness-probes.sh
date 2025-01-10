#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

NAMESPACE="$("$APPLY_NAMESPACE_TOOL" "project-other" "$VERSION_BRANCH" "$ERROR_LOG")"

get_pod_status_and_sleep(){
    kubectl get po --namespace "$NAMESPACE"
    sleep 5
}

main(){
    kubectl delete all --all --namespace "$NAMESPACE"
    $BUILD_AND_APPLY_TOOL "$WORKSPACE_FOLDER/project-other/apps/pingpong" "$NAMESPACE"
    $BUILD_AND_APPLY_TOOL "$WORKSPACE_FOLDER/project-other/apps/logserver" "$NAMESPACE"
    get_pod_status_and_sleep
    $BUILD_AND_APPLY_TOOL "$WORKSPACE_FOLDER/project-common/databases/postgres" "$NAMESPACE"
    for _ in {1..10}; do
        if get_pod_status_and_sleep | grep "2/2" > /dev/null; then
            get_pod_status_and_sleep
            exit 0
        fi
    done
}

main
