#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

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

get_pod_name() {
    kubectl get pods -l app="$1" -o jsonpath="{.items[0].metadata.name}"
}

get_container_names() {
    yq eval -e '.containerNames[]' "${1}"/manifests/values.yaml
}

build_images_for_app() {
    for container in $(get_container_names "${1}"); do
        docker build -f "${1}"/Dockerfile --target "${container}" -t "${container}:latest" "${1}"
        k3d image import "${container}:latest"
    done
}

build_and_apply() {
    build_images_for_app "$1"
    resolved_yaml="$("${RESOLVE_HELM_TEMPLATE_TOOL}" "${PWD}"/"${1}")"
    kubectl apply -f "${resolved_yaml}"
}

deploy_volumes() {
    mapfile -t VOLUME_NAMES < <(ls)
    for volume in "${VOLUME_NAMES[@]}"; do
        kubectl apply -f "$("${RESOLVE_HELM_TEMPLATE_TOOL}" "${PWD}"/"${volume}")"
    done
}

deploy_cronjobs() {
    mapfile -t JOB_NAMES < <(ls)
    for job in "${JOB_NAMES[@]}"; do
        build_and_apply "$job"
        job_name="${job}-run"
        job_fullname=job/"${job_name}"
        kubectl create job --from=cronjob/"${job}" "${job_name}"
        kubectl wait --for=condition=Complete --timeout=60s "${job_fullname}"
        kubectl logs "${job_fullname}"
    done
}

deploy_apps() {
    mapfile -t APP_NAMES < <(ls)
    for app in "${APP_NAMES[@]}"; do
        build_and_apply "$app"
        pod_name="$(get_pod_name "${app}")"
        kubectl wait --for=condition=Ready --timeout=30s pod/"${pod_name}"
        kubectl logs "${pod_name}"
    done
}

verify_lb_connectivity(){
    echo -n "Waiting that host.docker.internal:8081 can be reached ..."
    until curl --silent --fail host.docker.internal:8081 > /dev/null; do
        echo -n "."
        sleep 3
    done
    echo " OK"
}

if [[ -n "${1:-}" ]]; then
    cd "${WORKSPACE_FOLDER}/$1/.."
    build_and_apply "$(basename "${WORKSPACE_FOLDER}/$1")"
else
    create_cluster
    (cd "${WORKSPACE_FOLDER}"/project/volumes && deploy_volumes)
    (cd "${WORKSPACE_FOLDER}"/project/jobs && deploy_cronjobs)
    (cd "${WORKSPACE_FOLDER}"/project/apps && deploy_apps)
    kubectl cluster-info
    kubectl get svc,ing
    verify_lb_connectivity
fi
