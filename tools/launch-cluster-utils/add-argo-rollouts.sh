#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

add_argo_rollouts(){
    kubectl create namespace argo-rollouts
    kubectl apply --namespace argo-rollouts -f "$ARGO_DOWNLOAD_URL/install.yaml"
}
add_argo_rollouts
