#!/bin/bash

set -euo pipefail

IMAGE_TAG="$1"
LOCK_FILE="$HOME/.k3d-lock"

cleanup() {
    rm "$LOCK_FILE"
}

get_image_sha() {
    if output="$(docker inspect --format='{{.Id}}' "$IMAGE_TAG" 2>&1)"; then
        echo "$output"
    else
        echo "$output" | grep -v "Error: No such object: " || true
        return 1
    fi
}

image_available() {
    if output="$(docker exec k3d-k3s-default-agent-0 crictl inspecti "${IMAGE_SHA}" 2>&1)"; then
        echo "$output" | grep "$IMAGE_TAG" || return 1
        return 0
    else
        echo "$output" | grep -v "Error: No such object: " || true
        return 1
    fi
}

main() {
    IMAGE_SHA="$(get_image_sha)"
    if [ -z "${CI:-}" ]; then
        if ! image_available; then
            while [[ -f "$LOCK_FILE" ]]; do
                echo "Waiting for another k3d process to be finished..."
                sleep 1
            done
            touch "$LOCK_FILE"
            trap cleanup EXIT
            k3d image import "$IMAGE_TAG"
        fi
    fi
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi
main
