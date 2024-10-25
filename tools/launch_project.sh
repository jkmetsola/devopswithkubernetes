#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

get_pod_name() {
    app_name="$(yq eval -e '.containerNames[0]' "${1}"/manifests/values.yaml)"
    kubectl get pods -l app="$app_name" -o jsonpath="{.items[0].metadata.name}"
}

get_container_names() {
    yq eval -e '.containerNames[]' "${1}"/manifests/values.yaml
}

get_image_sha() {
    docker inspect --format='{{.Id}}' "$1"
}

image_available() {
    docker exec k3d-k3s-default-agent-0 crictl inspecti "${1}" > /dev/null
}

build_images_for_app() {
    for container in $(get_container_names "${1}"); do
        image_tag="${container}:latest"
        image_sha="$(get_image_sha "${image_tag}")"
        "${SYMLINK_TOOL}" "${PWD}/$1"
        docker build -f "${1}"/Dockerfile --target "${container}" -t "${image_tag}" "${1}"
        if [[ "${image_sha}" != "$(get_image_sha "${image_tag}")" ]]; then
            k3d image import "${image_tag}"
        elif ! image_available "${image_tag}"; then
            k3d image import "${image_tag}"
        fi
    done
}

build_and_apply() {
    build_images_for_app "$1"
    apply_manifests "$1"
}

apply_secrets() {
    secrets_file="${PWD}/${1}/manifests/secret.enc.yaml"
    secrets_file_decrypted="${PWD}/${1}/manifests/secret.yaml"
    if [[ -f "$secrets_file" ]]; then
        if [[ -f "$secrets_file_decrypted" && "$secrets_file" -ot "$secrets_file_decrypted" ]]; then
            "$AGE_KEY_TOOL" "$secrets_file_decrypted"
        fi
        "$AGE_KEY_TOOL" "$secrets_file" | kubectl apply -f -
    fi
}

apply_manifests() {
    resolved_yaml="$("${RESOLVE_HELM_TEMPLATE_TOOL}" "${PWD}"/"${1}")"
    kubectl apply -f "${resolved_yaml}"
    apply_secrets "$1"
}

sorted_apps() {
    tmp_sorted_apps_file="$(mktemp)"
    "$WORKSPACE_FOLDER"/tools/sort_apps_tool.py "${PWD}" "$tmp_sorted_apps_file"
    echo "$tmp_sorted_apps_file"
}

deploy_non_image_folders() {
    mapfile -t OTHER_APPS < "$(sorted_apps)"
    for other_app in "${OTHER_APPS[@]}"; do
        apply_manifests "$other_app"
    done
}

deploy_cronjobs() {
    mapfile -t JOB_NAMES < "$(sorted_apps)"
    for job in "${JOB_NAMES[@]}"; do
        build_and_apply "$job"
        kubectl create job --from=cronjob/"${job}" "${job}"-run
        kubectl wait --all --for=condition=Complete --timeout=60s job -l job="${job}"
        kubectl logs -l job="${job}"
    done
}

deploy_apps() {
    mapfile -t APP_NAMES < "$(sorted_apps)"
    for app in "${APP_NAMES[@]}"; do
        build_and_apply "$app"
        wait_for_pod "$app"
    done
}

wait_for_pod() {
    kubectl wait --all --for=condition=Ready --timeout=30s pod -l app="$1"
    kubectl logs --all-containers -l app="$1"
}

verify_frontpage_connectivity(){
    echo -n "Waiting that host.docker.internal:8081 can be reached ..."
    until curl --silent --fail host.docker.internal:8081 > /dev/null; do
        echo -n "."
        sleep 3
    done
    echo " OK"
}

init_project(){
    kubectl delete namespace --now "$1" || true
    kubectl create namespace "$1"
    kubectl config set-context --current --namespace="$1"
}

launch_projects() {
    if [[ "${1:-}" == "$(basename "${PROJECT_FOLDER}")" ]]; then
        (cd "${PROJECT_FOLDER}"/volumes && deploy_non_image_folders)
        (cd "${PROJECT_FOLDER}"/jobs && deploy_cronjobs)
        (cd "${PROJECT_FOLDER}"/apps && deploy_apps)
        verify_frontpage_connectivity
    elif [[ "${1:-}" == "$(basename "${PROJECT_OTHER_FOLDER}")" ]]; then
        (cd "${PROJECT_OTHER_FOLDER}"/volumes && deploy_non_image_folders)
        (cd "${PROJECT_OTHER_FOLDER}"/apps && deploy_apps)
    fi
    kubectl cluster-info
    kubectl get svc,ing
}

main() {
    if [[ -n "${DEBUG:-}" ]]; then
        set -x
        export DEBUG
    fi

    if [[ "${1}" == "$(basename "${PROJECT_FOLDER}")" || "${1}" == "$(basename "${PROJECT_OTHER_FOLDER}")" ]]; then
        init_project "$1"
        launch_projects "$1"
        exit 0
    fi

    if [[ -n "${1:-}" ]]; then
        app="$(basename "$1")"
        cd "${WORKSPACE_FOLDER}/$1/.."
        if ! build_and_apply "$app"; then
            echo "Error: Failed to deploy $1" >&2
            echo "Trying to only apply manifests..." >&2
            apply_manifests "$app"
        fi
        sleep 1
        kubectl delete --now=true pod -l app="$app"
        wait_for_pod "$app"
    fi
}

main "$1"
