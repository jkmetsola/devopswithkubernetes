#!/bin/bash

set -euo pipefail

APPS_DIR=$1
NAMESPACE=$2

COMMANDS=()

deploy_apps() {
    mapfile -t APP_NAMES < <($GET_BASENAMES_TOOL "$APPS_DIR")
    for app in "${APP_NAMES[@]}"; do
        APP_DIR=$APPS_DIR/$app
        COMMANDS+=(
            "$BUILD_AND_APPLY_TOOL $APP_DIR $NAMESPACE && \
            timeout --verbose 90 $WAIT_FOR_POD_TOOL $app $NAMESPACE"
        )
    done
    $START_AND_WAIT_SUBPROCESSES "${COMMANDS[@]}"
}

main() {
    deploy_apps
}

main
