#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

APP_DIR=$1
NAMESPACE=$2

"$WORKSPACE_FOLDER"/tools/launch-project-utils/build-docker-images-for-app.sh \
    "$APP_DIR" \
    "$ERROR_LOG"
"$APPLY_MANIFESTS_TOOL" "$APP_DIR" "$NAMESPACE"
