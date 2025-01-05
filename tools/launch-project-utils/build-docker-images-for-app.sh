#!/bin/bash

set -euo pipefail

APP_DIR=$1

APP="$(basename "$APP_DIR")"
WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

get_full_values_yaml() {
    SHOW_FULL_VALUES=true "${RESOLVE_HELM_TEMPLATE_TOOL}" "${APP_DIR}"
}

get_container_names() {
    yq eval -e '.containerNames[]' "$(get_full_values_yaml "${APP}")"
}

build_images_for_app() {
    for container in $(get_container_names); do
        "$WORKSPACE_FOLDER"/tools/launch-project-utils/build-docker-image-for-container.sh \
            "$container" \
            "$APP_DIR"
    done
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi
build_images_for_app
