#!/bin/bash

set -euo pipefail

APPS_DIR=$1
NAMESPACE=$2

DEPLOYMENT_PIDS=()

wait_for_deployment_pids(){
    for deployment_pid in "${DEPLOYMENT_PIDS[@]}"; do
        wait "$deployment_pid"
    done
}

deploy_apps() {
    mapfile -t APP_NAMES < <($GET_BASENAMES_TOOL "$APPS_DIR")
    for app in "${APP_NAMES[@]}"; do
        temp_app_log="$(mktemp)"
        echo "Outputting $app application logs to $temp_app_log"
        (
            $BUILD_AND_APPLY_TOOL "$APPS_DIR/$app" "$NAMESPACE"
            $WAIT_FOR_POD_TOOL "$app" "$NAMESPACE"
        ) > "$temp_app_log" &
        DEPLOYMENT_PIDS+=($!)
    done
    wait_for_deployment_pids
}

main() {
    if [[ -n "${DEBUG:-}" ]]; then
        set -x
        export DEBUG
    fi
    deploy_apps
}

main
