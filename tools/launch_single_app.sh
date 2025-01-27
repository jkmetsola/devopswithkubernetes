#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

APP_DIR=$WORKSPACE_FOLDER/$1

echo_errors_on_exit1() {
    if [ "$?" -eq 1 ]; then
        echo "Error logs available $ERROR_LOG" >&2
        exit 1
    fi
}

main() {
    app="$(basename "$APP_DIR")"
    project="$(basename "$(realpath "$APP_DIR/../..")")"
    NAMESPACE="$($APPLY_NAMESPACE_TOOL "$project" "$VERSION_BRANCH" "$ERROR_LOG")"
    kubectl delete --ignore-not-found --wait --namespace "$NAMESPACE" --now=true deployment "$app"
    $BUILD_AND_APPLY_TOOL "$APP_DIR" "$NAMESPACE"
    timeout --verbose 90 "$WAIT_FOR_POD_TOOL" "$app" "$NAMESPACE"
}

trap echo_errors_on_exit1 EXIT
main
