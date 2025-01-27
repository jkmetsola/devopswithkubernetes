#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

CONTAINER=$1
APP_DIR=$2

IMAGE_TAG="europe-north1-docker.pkg.dev/$PROJECT_ID/dwk/$CONTAINER:$VERSION_TAG"
DOCKER_BUILD_TOOL="$WORKSPACE_FOLDER"/tools/launch-project-utils/build-docker-image.sh
DOCKER_PUSH_TOOL="$WORKSPACE_FOLDER"/tools/launch-project-utils/push-docker-image.sh
IMPORT_K3D_IMAGE_TOOL="$WORKSPACE_FOLDER"/tools/launch-project-utils/import-image-to-k3d.sh

main() {
    "${SYMLINK_TOOL}" "$APP_DIR"
    if ! docker pull "$IMAGE_TAG" 2> "$ERROR_LOG" | grep "Status: Image is up to date"; then
        "$DOCKER_BUILD_TOOL" "$APP_DIR" "$CONTAINER" "$IMAGE_TAG"
    fi
    "$DOCKER_PUSH_TOOL" "$IMAGE_TAG"
    "$IMPORT_K3D_IMAGE_TOOL" "$IMAGE_TAG"
}

main
