#!/bin/bash

set -euo pipefail

GLOBAL_VALUES_FILE="./global-values.yaml"
POD_NAMES=()
POD_NAMES+=("$(yq eval '.projectAppName' ${GLOBAL_VALUES_FILE})")
POD_NAMES+=("$(yq eval '.pingPongAppName' ${GLOBAL_VALUES_FILE})")
POD_NAMES+=("$(yq eval '.randomLogServerAppName' ${GLOBAL_VALUES_FILE})")


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
    docker exec k3d-k3s-default-agent-0 mkdir -p /tmp/kube
}

resolved_yaml() {
    temp_production_yaml="$(mktemp --suffix .yaml)"
    temp_resolved_production_yaml="$(mktemp --suffix .yaml)"
    eval helm template "${1}" -f "${GLOBAL_VALUES_FILE}" ./"${1}"/manifests "${2:-}" "${3:-}" > "${temp_production_yaml}"
    yq eval 'explode(.)' "${temp_production_yaml}" > "${temp_resolved_production_yaml}"
    echo "${temp_resolved_production_yaml}"
}

get_pod_name() {
    kubectl get pods -l app="$1" -o jsonpath="{.items[0].metadata.name}"
}

get_pod_container_count() {
    yq eval '.spec.template.spec.containers | length' \
    "$(resolved_yaml "${1}" --show-only "templates/deployment.yaml")"
}

get_pod_containers() {
    yq eval '.spec.template.spec.containers[].name' "$(resolved_yaml "${1}" \
    --show-only "templates/deployment.yaml")"
}

build_image() {
    tag="${3:-${1}}":latest
    eval docker build -f "${1}"/Dockerfile "${2:-}" "${3:-}" -t "${tag}" "${1}"
    k3d image import "${tag}"
}

build_images_for_pod() {
    for container in $(get_pod_containers "${pod}"); do
        build_image "${pod}" --target "${container}"
    done
}

deploy_pods() {
    for pod in "${POD_NAMES[@]}"; do
        if [[ "$(get_pod_container_count "${pod}")" -gt 1 ]]; then
            build_images_for_pod "$pod"
        else
            build_image "$pod"
        fi
        kubectl apply -f "$(resolved_yaml "${pod}")"
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
deploy_pods
kubectl cluster-info
kubectl get svc,ing
verify_lb_connectivity
