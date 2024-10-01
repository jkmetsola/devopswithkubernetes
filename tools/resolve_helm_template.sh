#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

APP_DIR="$1"
APP_NAME="$(basename "$APP_DIR")"
MANIFESTS_DIR="$1"/manifests
APP_FILES_DIR="$1"/script_templates
TEMP_DEP_VARS="$1"/manifests/dependency-values.yaml

check_for_new_helm_errors() {
    if grep -v "found symbolic link in path:" "${temp_error_log}" >&2; then
        echo "New errors seen in helm template output. Please check." >&2
        exit 1
    fi
}

cleanup() {
    check_for_new_helm_errors
    rm -f "${TEMP_DEP_VARS}" "${temp_production_yaml}" "${temp_error_log}" \
    "${MANIFESTS_DIR}/templates/configMap.yaml" "${MANIFESTS_DIR}/Chart.yaml"
}

build_configmap_template() {
    if [[ -d "$APP_FILES_DIR" ]]; then
        {
            echo '---'
            echo '{{- with .Values}}'
            first_container_name="$(yq eval -e '.containerNames[0]' "$APP_DIR"/manifests/values.yaml)"
            kubectl create configmap "${first_container_name}" \
                --dry-run=client \
                --from-file "$APP_FILES_DIR" \
                -o yaml
            echo '{{- end}}'
        } > "${MANIFESTS_DIR}/templates/configMap.yaml"
    fi
}

create_chart_file() {
    echo \
"---
apiVersion: v2
name: ${APP_NAME}
description: A Helm chart for Kubernetes
version: 0.1.0
" > "${MANIFESTS_DIR}/Chart.yaml"
}

resolve_template() {
    temp_production_yaml="$(mktemp --suffix .yaml)"
    temp_resolved_production_yaml="$(mktemp --suffix .yaml)"
    temp_error_log="$(mktemp --suffix .log)"
    trap 'cleanup' EXIT
    helm template --generate-name -f "${TEMP_DEP_VARS}" "${MANIFESTS_DIR}" \
        > "${temp_production_yaml}" 2> "${temp_error_log}"
    yq eval -e 'explode(.)' "${temp_production_yaml}" > "${temp_resolved_production_yaml}"
    echo "${temp_resolved_production_yaml}"
}

resolve_dependency_values() {
    "${WORKSPACE_FOLDER}"/tools/dependency_value_tool.py \
        "${APP_DIR}" \
        "${WORKSPACE_FOLDER}"/global-values.yaml \
        "${TEMP_DEP_VARS}"
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi

resolve_dependency_values
create_chart_file
build_configmap_template
resolve_template
