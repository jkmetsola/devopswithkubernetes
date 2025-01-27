#!/bin/bash

set -euo pipefail

IMAGE_TAG=$1

docker_push_image() {
    if [[ "$(kubectl config current-context)" != "k3d-k3s-default" ]]; then
        docker push "$IMAGE_TAG"
    fi
}

docker_push_image
