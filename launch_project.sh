#!/bin/bash

set -euo pipefail

GLOBAL_VALUES_FILE="./global-values.yaml"

SIMPLE_SERVER_APP="$(yq eval '.simpleServerAppName' ${GLOBAL_VALUES_FILE})"
PINGPONG_APP="$(yq eval '.pingPongAppName' ${GLOBAL_VALUES_FILE})"
LOG_SERVER_APP="$(yq eval '.randomLogServerAppName' ${GLOBAL_VALUES_FILE})"
RANDOM_STRING_CONTAINER="$(yq eval '.randomStringContainerName' random-log-server/manifests/values.yaml)"
POD_NAMES=("$LOG_SERVER_APP" "${SIMPLE_SERVER_APP}" "${PINGPONG_APP}")
IMAGE_NAMES=("${POD_NAMES[@]}" "${RANDOM_STRING_CONTAINER}")

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

build_image() {
    if ! docker build -f "${1}"/Dockerfile --target "${1}" -t "${1}":latest "${1}";then
        docker build -f "${1}"/Dockerfile -t "${1}":latest "${1}"
    fi
    k3d image import "${1}":latest
}

build_images() {
    # Because there are 2 images in same pod, create temporary symlink to avoid creating different logic
    ln -s "${LOG_SERVER_APP}" "${RANDOM_STRING_CONTAINER}"
    trap 'rm -f ${RANDOM_STRING_CONTAINER}' EXIT
    for image in "${IMAGE_NAMES[@]}"; do
        build_image "$image"
    done
    rm -f "${RANDOM_STRING_CONTAINER}"
}

deploy_pods() {
    for pod in "${POD_NAMES[@]}"; do
        temp_production_yaml="$(mktemp --suffix .yaml)"
        temp_resolved_production_yaml="$(mktemp --suffix .yaml)"
        helm template "${pod}" -f "${GLOBAL_VALUES_FILE}" ./"${pod}"/manifests > "${temp_production_yaml}"
        yq eval 'explode(.)' "${temp_production_yaml}" > "${temp_resolved_production_yaml}"
        kubectl apply -f "${temp_resolved_production_yaml}"
    done
}

wait_pods() {
    for pod in "${POD_NAMES[@]}"; do
        pod_name="$(get_pod_name "${pod}")"
        kubectl wait --for=condition=Ready --timeout=30s pod/"${pod_name}"
        kubectl logs "${pod_name}"
    done
}

verify_lb_connectivity(){
    echo -n "Waiting that host.docker.internal:8081 can be reached ..."
    until curl --silent --fail -o "$(mktemp)" host.docker.internal:8081; do
        echo -n "."
        sleep 3
    done
    echo " OK"
}

create_cluster
build_images
deploy_pods
wait_pods
kubectl cluster-info
kubectl get svc,ing
verify_lb_connectivity
