#!/bin/bash

set -euo pipefail

APP_DIR="$1"
MANIFESTS_DIR="$1/manifests"
APP_FILES_DIR="$1"/script_templates

check_for_new_helm_errors() {
    if grep -v "found symbolic link in path:" "${temp_error_log}" >&2; then
        echo "New errors seen in helm template output. Please check." >&2
        exit 1
    fi
}

cleanup() {
    check_for_new_helm_errors
    rm -f "${temp_production_yaml}" "${temp_error_log}" "${MANIFESTS_DIR}/templates/configMap.yaml"
}

build_configmap_template() {
    if [[ -d "$APP_FILES_DIR" ]]; then
        {
            echo '---'
            echo '{{- with .Values}}'
            kubectl create configmap "$(basename "$APP_DIR")" \
                --dry-run=client \
                --from-file "$APP_FILES_DIR" \
                -o yaml
            echo '{{- end}}'

        } > "${MANIFESTS_DIR}/templates/configMap.yaml"
    fi
}

resolve_template() {
    temp_production_yaml="$(mktemp --suffix .yaml)"
    temp_resolved_production_yaml="$(mktemp --suffix .yaml)"
    temp_error_log="$(mktemp --suffix .log)"
    trap 'cleanup' EXIT
    helm template --generate-name -f "${MANIFESTS_DIR}/global-values.yaml" "${MANIFESTS_DIR}" \
        > "${temp_production_yaml}" 2> "${temp_error_log}"
    yq eval -e 'explode(.)' "${temp_production_yaml}" > "${temp_resolved_production_yaml}"
    echo "${temp_resolved_production_yaml}"
}

build_configmap_template
resolve_template
