#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

APP_DIR="$1"
APP_NAME="$(basename "$APP_DIR")"

APP_FILES_DIR="$APP_DIR"/script_templates
APP_ENV_FILE="$APP_DIR"/.env
MANIFESTS_DIR="$APP_DIR"/manifests
TEMPLATES_DIR="$MANIFESTS_DIR"/templates
VALUES_YAML_FILE="$MANIFESTS_DIR"/values.yaml
TEMP_DEP_VARS="$MANIFESTS_DIR"/dependency-values.yaml

FULL_VALUES_YAML="$(mktemp --suffix .yaml)"
TEMP_ERROR_LOG="$(mktemp --suffix .log)"
TEMP_PRODUCTION_YAML="$(mktemp --suffix .yaml)"
TEMP_RESOLVED_PRODUCTION_YAML="$(mktemp --suffix .yaml)"
FULL_CONFIGMAP_TMP="$(mktemp --suffix .yaml)"
TMP_PARTIAL_TEMPLATES_PREFIX=_tmp_
SCRIPT_NAME="$(basename "$0")"

get_deployment_specific_values_file(){
    cluster_name="$(kubectl config current-context)"
    if [[ "$cluster_name" == "gke_dwk-gke-440513_europe-north1-b_dwk-cluster" ]]; then
        echo "$WORKSPACE_FOLDER/gke-specific-values.yaml"
    elif [[ "$cluster_name" == "k3d-k3s-default" ]]; then
        echo "$WORKSPACE_FOLDER/k3d-specific-values.yaml"
    fi
}

check_for_new_helm_errors() {
    if grep -v "found symbolic link in path:" "${TEMP_ERROR_LOG}" >&2; then
        echo "New errors seen in helm template output. Please check." >&2
        resolve_template true || true
        echo "Full yaml: $TEMP_PRODUCTION_YAML" >&2
        echo "Full yaml exploded: $TEMP_RESOLVED_PRODUCTION_YAML" >&2
        exit 1
    fi
}

clean_tmp_partial_templates(){
    find "$TEMPLATES_DIR/" -regex "^.*${TMP_PARTIAL_TEMPLATES_PREFIX}.*[.]tpl" -exec rm -f {} +
}

clean_copied_symlinks(){
    find "$APP_DIR" -name "*.symlink" | while read -r file; do
        basename=$(basename "$file" .symlink)
        directory=$(dirname "$file")
        if [[ -e "$directory/$basename" && -e "$directory/$basename.symlink" ]]; then
            rm -f "$directory/$basename"
        fi
    done
}

cleanup() {
    if [ "$?" -eq 1 ]; then
        echo "'$SCRIPT_NAME $APP_DIR' exited with code 1" >&2
        check_for_new_helm_errors
        exit 1
    fi
    check_for_new_helm_errors
    rm -f \
    "${TEMP_DEP_VARS}" \
    "${TEMP_PRODUCTION_YAML}" \
    "${TEMP_ERROR_LOG}" \
    "${TEMPLATES_DIR}/configMap.yaml" \
    "${MANIFESTS_DIR}/Chart.yaml" \
    "${FULL_CONFIGMAP_TMP}"
    clean_tmp_partial_templates
    clean_copied_symlinks
}

build_configmap_if_needed() {
    if [[ -f "$APP_ENV_FILE" || -d "$APP_FILES_DIR" ]]; then
        build_configmap_template > "${TEMPLATES_DIR}/configMap.yaml"
    fi
}

build_configmap_template() {
    first_container_name="$(yq eval -e '.containerNames[0]' "$(full_values_yaml)")"
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

copy_partial_templates(){
    for file in "$BASE_TEMPLATES_DIR"/*; do
        filename=$(basename "$file")
        dest_file="$TEMPLATES_DIR/${TMP_PARTIAL_TEMPLATES_PREFIX}${filename}"
        if [[ ! -e "$TEMPLATES_DIR/$filename" ]]; then
            cp "$file" "$dest_file"
        fi
    done
}

resolve_template() {
    trap 'cleanup' EXIT
    helm template --generate-name \
        ${1:+--debug }\
        --set versionTag="$VERSION_TAG" \
        -f "$(get_deployment_specific_values_file)" \
        -f "${TEMP_DEP_VARS}" \
        "${MANIFESTS_DIR}" \
        > "${TEMP_PRODUCTION_YAML}" 2> "${TEMP_ERROR_LOG}"
    yq eval -e 'explode(.)' "${TEMP_PRODUCTION_YAML}" > "${TEMP_RESOLVED_PRODUCTION_YAML}"
    echo "${TEMP_RESOLVED_PRODUCTION_YAML}"
}

resolve_dependency_values() {
    "${WORKSPACE_FOLDER}"/tools/dependency_value_tool.py \
        --values-yaml "$VALUES_YAML_FILE" \
        --global-values-yaml "${WORKSPACE_FOLDER}"/global-values.yaml \
        --resolved-values-yaml "${TEMP_DEP_VARS}"
}

full_values_yaml() {
    yq -n "load(\"${TEMP_DEP_VARS}\") * load(\"${VALUES_YAML_FILE}\")" > "$FULL_VALUES_YAML"
    echo "$FULL_VALUES_YAML"
}

main() {

    resolve_dependency_values
    if [[ -n "${SHOW_FULL_VALUES:-}" ]]; then
        full_values_yaml
        exit 0
    fi

    create_chart_file
    build_configmap_if_needed
    copy_partial_templates
    resolve_template
}

main
