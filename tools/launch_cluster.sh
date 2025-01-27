#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

install_plugins() {
    commands=(
        "$WORKSPACE_FOLDER/tools/launch-cluster-utils/add-argo-rollouts.sh"
        "$WORKSPACE_FOLDER/tools/launch-cluster-utils/add-loki.sh"
        "$WORKSPACE_FOLDER/tools/launch-cluster-utils/add-prometheus.sh"
    )
    STDERR_TO_FILE=true $START_AND_WAIT_SUBPROCESSES "${commands[@]}"
}

create_cluster() {
    k3d cluster delete
    k3d cluster create \
        --host-alias 0.0.0.0:host.docker.internal \
        --agents 2 \
        --k3s-arg "--tls-san=host.docker.internal@server:0" \
        --port 8081:80@loadbalancer \
        --api-port host.docker.internal:6550 \
        --wait
    install_plugins
    kubectl port-forward --namespace loki-stack --address 0.0.0.0 service/loki-grafana 3000:80 &
    kubectl port-forward --namespace prometheus --address 0.0.0.0 service/prometheus-grafana 3001:80 &
    kubectl port-forward \
        --namespace prometheus \
        --address 0.0.0.0 \
        service/prometheus-kube-prometheus-prometheus 9090:9090 &
}

create_cluster
