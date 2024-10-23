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

build_images_for_app() {
    for container in $(get_container_names "${1}"); do
        image_tag="${container}:latest"
        image_sha="$(get_image_sha "${image_tag}")"
        docker build -f "${1}"/Dockerfile --target "${container}" -t "${image_tag}" "${1}"
        if [[ "${image_sha}" != "$(get_image_sha "${image_tag}")" ]]; then
            k3d image import "${container}:latest"
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
        if [[ -f "$secrets_file_decrypted" ]]; then
            "$WORKSPACE_FOLDER"/tools/age_key_tool.sh "$secrets_file_decrypted"
        fi
        "$WORKSPACE_FOLDER"/tools/age_key_tool.sh "$secrets_file" | kubectl apply -f -
    fi
}

apply_manifests() {
    resolved_yaml="$("${RESOLVE_HELM_TEMPLATE_TOOL}" "${PWD}"/"${1}")"
    kubectl apply -f "${resolved_yaml}"
    apply_secrets "$1"
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

deploy_non_image_folders() {
    mapfile -t OTHER_APPS < <(sorted_apps)
    for other_app in "${OTHER_APPS[@]}"; do
        apply_manifests "$other_app"
    done
}

deploy_cronjobs() {
    mapfile -t JOB_NAMES < <(sorted_apps)
    for job in "${JOB_NAMES[@]}"; do
        build_and_apply "$job"
        kubectl create job --from=cronjob/"${job}" "${job}"-run
        kubectl wait --all --for=condition=Complete --timeout=60s job -l job="${job}"
        kubectl logs -l job="${job}"
    done
}

deploy_apps() {
    mapfile -t APP_NAMES < <(sorted_apps)
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
    kubectl delete namespace "$1" || true
    kubectl create namespace "$1"
    kubectl config set-context --current --namespace="$1"
}

launch_projects() {
    if [[ "${1:-}" == "project" ]]; then
        (cd "${PROJECT_FOLDER}"/volumes && deploy_non_image_folders)
        (cd "${PROJECT_FOLDER}"/jobs && deploy_cronjobs)
        (cd "${PROJECT_FOLDER}"/apps && deploy_apps)
        verify_frontpage_connectivity
    elif [[ "${1:-}" == "project-other" ]]; then
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

    if [[ "${1}" == "project" || "${1}" == "project-other" ]]; then
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
        kubectl delete --now=true pod -l app="$app"
        wait_for_pod "$app"
    fi
}

main "$1"
