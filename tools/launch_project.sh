#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"
PROJECT_DIR="${WORKSPACE_FOLDER}/${PROJECT_FOLDER_NAME}"

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
    app_name="$(yq eval -e '.containerNames[0]' "${1}"/manifests/values.yaml)"
    kubectl get pods -l app="$app_name" -o jsonpath="{.items[0].metadata.name}"
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

sorted_apps() {
    file_count=$(find . -mindepth 2 -maxdepth 2 -regex '.*/[0-9][0-9]\.order' | wc -l)
    dir_count=$(find . -mindepth 1 -maxdepth 1 -type d | wc -l)
    if [[ $file_count -ne $dir_count ]]; then
        echo "Error: The number of order files does not match the number of directories." >&2
        exit 1
    fi
    find . -mindepth 2 -maxdepth 2 -regex '.*/[0-9][0-9]\.order' -print0 \
    | xargs -0n 1 basename | sort \
    | xargs -n 1 find . -name \
    | xargs -n 1 dirname \
    | xargs -n 1 basename
}

deploy_volumes() {
    mapfile -t VOLUME_NAMES < <(sorted_apps)
    for volume in "${VOLUME_NAMES[@]}"; do
        kubectl apply -f "$("${RESOLVE_HELM_TEMPLATE_TOOL}" "${PWD}"/"${volume}")"
    done
}

deploy_cronjobs() {
    mapfile -t JOB_NAMES < <(sorted_apps)
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
    mapfile -t APP_NAMES < <(sorted_apps)
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

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi

if [[ -n "${1:-}" ]]; then
    cd "${WORKSPACE_FOLDER}/$1/.."
    build_and_apply "$(basename "${WORKSPACE_FOLDER}/$1")"
else
    create_cluster
    (cd "${PROJECT_DIR}"/volumes && deploy_volumes)
    (cd "${PROJECT_DIR}"/jobs && deploy_cronjobs)
    (cd "${PROJECT_DIR}"/apps && deploy_apps)
    kubectl cluster-info
    kubectl get svc,ing
    verify_lb_connectivity
fi
