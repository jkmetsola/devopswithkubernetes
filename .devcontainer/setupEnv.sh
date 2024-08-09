#!/bin/bash
set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

TEMP_BUILD_ENV_FILE=$(mktemp)
TEMP_BUILDARG_FILE=$(mktemp)
cleanup() {
    rm -f "$TEMP_BUILD_ENV_FILE" "$TEMP_BUILDARG_FILE"
}
trap 'cleanup' EXIT

"$WORKSPACE_FOLDER"/.devcontainer/configure_devcontainer_json.py \
    --host-docker-gid "$(getent group docker | cut -d: -f3)" \
    --host-uid "$(id -u)" \
    --host-gid "$(id -g)" \
    --build-arg-output-file "${TEMP_BUILDARG_FILE}" \
    --build-env-output-file "${TEMP_BUILD_ENV_FILE}" \
    --modify-devcontainer-json "$1"
# shellcheck disable=SC1090
. "$TEMP_BUILD_ENV_FILE"