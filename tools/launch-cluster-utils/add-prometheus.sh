#!/bin/bash

set -euo pipefail

add_prometheus(){
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add stable https://charts.helm.sh/stable
    kubectl create namespace prometheus
    helm install prometheus --debug prometheus-community/kube-prometheus-stack \
        --version 67.5.0 \
        --namespace prometheus \
        --wait
}

add_prometheus
