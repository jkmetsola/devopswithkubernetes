#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

APP_DIR=$1
NAMESPACE=$2

apply_manifests() {
    resolved_yaml="$("${RESOLVE_HELM_TEMPLATE_TOOL}" "${APP_DIR}")"
    kubectl apply --namespace "$NAMESPACE" -f "${resolved_yaml}"
    "$WORKSPACE_FOLDER"/tools/launch-project-utils/apply-secrets.sh \
        "${APP_DIR}" \
        "${NAMESPACE}"
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi

apply_manifests
