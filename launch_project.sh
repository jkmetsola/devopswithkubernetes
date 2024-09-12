#!/bin/bash

set -euo pipefail

RANDOM_STRING_APP=excercise101
SIMPLE_WEB_SERVER_APP=simple-server

create_cluster() {
    k3d cluster delete
    k3d cluster create \
        --host-alias 0.0.0.0:host.docker.internal \
        --agents 2 \
        --k3s-arg "--tls-san=host.docker.internal@server:0" \
        --port 8081:80@loadbalancer
    KUBE_API_ADDRESS="$(kubectl config view -o jsonpath='{.clusters[?(@.name=="k3d-k3s-default")].cluster.server}')"
    PORT=$(echo "$KUBE_API_ADDRESS" | awk -F: '{print $NF}')
    kubectl config set clusters.k3d-k3s-default.server https://host.docker.internal:"$PORT"
}

get_pod_name() {
    kubectl get pods -l app="$1" -o jsonpath="{.items[0].metadata.name}"
}

deploy_apps() {
    for APP in "$@"; do
        docker build -f "${APP}"/Dockerfile -t "${APP}":latest "${APP}"
        k3d image import "${APP}":latest
        kubectl apply -f "${APP}"/manifests/
    done
}

wait_apps() {
    for APP in "$@"; do
        pod_name="$(get_pod_name "${APP}")"
        kubectl wait --for=condition=Ready --timeout=30s pod/"${pod_name}"
        kubectl logs "${pod_name}"
    done
}

create_cluster
deploy_apps $RANDOM_STRING_APP $SIMPLE_WEB_SERVER_APP
wait_apps $RANDOM_STRING_APP $SIMPLE_WEB_SERVER_APP
kubectl cluster-info
kubectl get svc,ing
until curl --silent --fail host.docker.internal:8081; do
  echo "Waiting host.docker.internal:8081"
  sleep 5
done
