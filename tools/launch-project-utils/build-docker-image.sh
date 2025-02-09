#!/bin/bash

set -euo pipefail

APP_DIR=$1
CONTAINER=$2
TAG=$3

TMP_DOCKER_BUILD_LOG="$(mktemp)"

docker_build() {
    docker build \
        --target "${CONTAINER}" \
        -t "$TAG" \
        "${APP_DIR}" \
        > "$TMP_DOCKER_BUILD_LOG" 2>&1
}

main() {
    if ! docker_build; then
        cat "$TMP_DOCKER_BUILD_LOG"
        return 1
    fi
}

main
