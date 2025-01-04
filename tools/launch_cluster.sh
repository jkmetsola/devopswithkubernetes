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

add_prometheus(){
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add stable https://charts.helm.sh/stable
    kubectl create namespace prometheus
    helm install prometheus --debug prometheus-community/kube-prometheus-stack \
        --version 67.5.0 \
        --namespace prometheus \
        --wait
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
    add_loki &
    add_prometheus &
    wait
    kubectl port-forward --namespace loki-stack --address 0.0.0.0 service/loki-grafana 3000:80 &
    kubectl port-forward --namespace prometheus --address 0.0.0.0 service/prometheus-grafana 3001:80 &
    exit 0
}

create_cluster
