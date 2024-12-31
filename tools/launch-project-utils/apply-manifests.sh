#!/bin/bash

set -euo pipefail

APP_DIR=$1
RESOLVE_HELM_TEMPLATE_TOOL=$2

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

apply_manifests() {
    resolved_yaml="$("${RESOLVE_HELM_TEMPLATE_TOOL}" "${APP_DIR}")"
    kubectl apply -f "${resolved_yaml}"
    "$WORKSPACE_FOLDER"/tools/launch-project-utils/apply-secrets.sh "${APP_DIR}"
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi

apply_manifests
