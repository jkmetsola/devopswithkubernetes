#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

add_loki(){
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    kubectl create namespace loki-stack
    helm install loki --debug grafana/loki-stack \
        --values "$WORKSPACE_FOLDER"/cluster-configuration/helm/grafana-loki-stack/values.yaml \
        --version 2.10.2 \
        --namespace loki-stack \
        --wait
}

add_loki
