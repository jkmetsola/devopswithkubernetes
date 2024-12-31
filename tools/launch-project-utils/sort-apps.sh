#!/bin/bash

set -euo pipefail

APPS_DIR=$1

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
TMP_SORTED_APPS_FILE="$(mktemp)"

main() {
    "$WORKSPACE_FOLDER"/tools/sort_apps_tool.py "${APPS_DIR}" "$TMP_SORTED_APPS_FILE"
    echo "$TMP_SORTED_APPS_FILE"
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi
main
