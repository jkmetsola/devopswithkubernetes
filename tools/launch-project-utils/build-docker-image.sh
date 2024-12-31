#!/bin/bash

set -euo pipefail

APP=$1
CONTAINER=$2
TAG=$3

TMP_DOCKER_BUILD_LOG="$(mktemp)"

docker_build() {
    docker build \
        -f "${APP}"/Dockerfile \
        --target "${CONTAINER}" \
        -t "$TAG" \
        "${APP}" \
        > "$TMP_DOCKER_BUILD_LOG" 2>&1
}

main() {
    if ! docker_build; then
        cat "$TMP_DOCKER_BUILD_LOG"
        return 1
    fi
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi
main
