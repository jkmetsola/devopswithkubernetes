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
APP_ENV_FILE="$1"/.env

TEMP_DEP_VARS="$1"/manifests/dependency-values.yaml

check_for_new_helm_errors() {
    if grep -v "found symbolic link in path:" "${temp_error_log}" >&2; then
        echo "New errors seen in helm template output. Please check." >&2
        exit 1
    fi
}

cleanup() {
    check_for_new_helm_errors
    rm -f \
    "${TEMP_DEP_VARS}" \
    "${temp_production_yaml}" \
    "${temp_error_log}" \
    "${MANIFESTS_DIR}/templates/configMap.yaml" \
    "${MANIFESTS_DIR}/Chart.yaml" \
    "${FULL_CONFIGMAP_TMP}"
}

build_configmap_if_needed() {
    FULL_CONFIGMAP_TMP="$(mktemp --suffix .yaml)"
    if [[ -f "$APP_ENV_FILE" || -d "$APP_FILES_DIR" ]]; then
        build_configmap_template > "${MANIFESTS_DIR}/templates/configMap.yaml"
    fi
}

build_configmap_template() {
    first_container_name="$(yq eval -e '.containerNames[0]' "$APP_DIR"/manifests/values.yaml)"
    if [[ -f "$APP_ENV_FILE" ]]; then
        configmap_env_tmp="$(mktemp --suffix .yaml)"
        kubectl create configmap "${first_container_name}" \
            --dry-run=client \
            --from-env-file "$APP_ENV_FILE" \
            -o yaml > "${configmap_env_tmp}"
    fi

    if [[ -d "$APP_FILES_DIR" ]]; then
        configmap_tmp="$(mktemp --suffix .yaml)"
        # --from-file ignores symlinks, so we need to manually copy the files
        # https://github.com/kubernetes/kubectl/blob/a499023/pkg/cmd/create/create_configmap.go#L54
        "${SYMLINK_TOOL}" "$APP_FILES_DIR"
        kubectl create configmap "${first_container_name}" \
            --dry-run=client \
            --from-file "$APP_FILES_DIR" \
            -o yaml > "${configmap_tmp}"
    fi

    if [[ -f "$APP_ENV_FILE" && -d "$APP_FILES_DIR" ]]; then
        yq -n "load(\"${configmap_tmp}\") * load(\"${configmap_env_tmp}\")" \
            > "${FULL_CONFIGMAP_TMP}"
    elif [[ ! -f "$APP_ENV_FILE" && -d "$APP_FILES_DIR" ]]; then
        mv "${configmap_tmp}" "${FULL_CONFIGMAP_TMP}"
    elif [[ -f "$APP_ENV_FILE" && ! -d "$APP_FILES_DIR" ]]; then
        mv "${configmap_env_tmp}" "${FULL_CONFIGMAP_TMP}"
    fi

    echo '---'
    echo '{{- with .Values}}'
    cat "${FULL_CONFIGMAP_TMP}"
    echo '{{- end}}'
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
build_configmap_if_needed
resolve_template
