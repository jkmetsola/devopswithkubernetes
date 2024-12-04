#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

get_full_values_yaml() {
    SHOW_FULL_VALUES=true "${RESOLVE_HELM_TEMPLATE_TOOL}" "${PWD}"/"${1}"
}

get_pod_name() {
    app_name="$(yq eval -e '.containerNames[0]' "$(get_full_values_yaml "${1}")")"
    kubectl get pods -l app="$app_name" -o jsonpath="{.items[0].metadata.name}"
}

get_container_names() {
    yq eval -e '.containerNames[]' "$(get_full_values_yaml "${1}")"
}

get_image_sha() {
    if image_sha="$(docker inspect --format='{{.Id}}' "$1")"; then
        echo "$image_sha"
    fi
}

image_available() {
    if [ -z "${CI:-}" ]; then
        docker exec k3d-k3s-default-agent-0 crictl inspecti "$1" > /dev/null || return 1
    fi
}

import_image_to_cluster() {
    if [ -z "${CI:-}" ]; then
        k3d image import "$1"
    fi
}

get_full_tag() {
    echo "europe-north1-docker.pkg.dev/$PROJECT_ID/dwk/$1:$VERSION_TAG"
}

docker_build_cmd() {
    app=$1
    container=$2
    image_tag=$3
    docker build \
        -f "${app}"/Dockerfile \
        --target "${container}" \
        -t "$image_tag" \
        "${app}" \
        > "$TMP_DOCKER_BUILD_LOG" 2>&1
}

docker_build_image(){
    app=$1
    container=$2
    tag=$3
    if ! docker_build_cmd "$app" "$container" "$tag"; then
        cat "$TMP_DOCKER_BUILD_LOG"
        return 1
    fi
}

docker_push_image() {
    if [[ "$(kubectl config current-context)" != "k3d-k3s-default" ]]; then
        remote_digests="$(docker image inspect "$image_tag-remote" -f '{{.RepoDigests}}')"
        local_digests="$(docker image inspect "$image_tag" -f '{{.RepoDigests}}')"
        if [[ "$local_digests" != "$remote_digests" ]]; then
            docker push "$image_tag"
        fi
    fi
}

build_images_for_app() {
    for container in $(get_container_names "${1}"); do
        image_tag="$(get_full_tag "${container}")"
        image_sha="$(get_image_sha "${image_tag}")"
        "${SYMLINK_TOOL}" "${PWD}/$1"
        TMP_DOCKER_BUILD_LOG=$(mktemp)
        docker_build_image "$1" "$container" "$image_tag"
        if ! docker pull "$image_tag" | grep "Status: Image is up to date"; then
            docker_build_image "$1" "$container" "$image_tag" || return 1
            docker_push_image
        fi
        if [[ "${image_sha}" != "$(get_image_sha "${image_tag}")" ]]; then
            import_image_to_cluster "$image_tag"
        elif ! image_available "${image_tag}"; then
            import_image_to_cluster "$image_tag"
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
    kubectl wait --all --for=condition=Ready --timeout=60s pod -l app="$1"
    kubectl logs --all-containers -l app="$1"
}

init_project() {
    if [[ $VERSION_BRANCH = "main" && "$1" = "project" ]]; then
        namespace="default"
    else
        namespace="$1-$VERSION_BRANCH"
    fi
    kubectl create namespace "$namespace" || kubectl get namespace "$namespace"
    kubectl config set-context --current --namespace="$namespace"
}

launch_projects() {
    if [[ "${1:-}" == "$(basename "${PROJECT_FOLDER}")" ]]; then
        (cd "${PROJECT_FOLDER}"/databases && deploy_apps)
        (cd "${PROJECT_FOLDER}"/initjobs && deploy_cronjobs)
        (cd "${PROJECT_FOLDER}"/apps && deploy_apps)
        (cd "${PROJECT_FOLDER}"/postjobs && deploy_cronjobs)
    elif [[ "${1:-}" == "$(basename "${PROJECT_OTHER_FOLDER}")" ]]; then
        (cd "${PROJECT_FOLDER}"/databases && deploy_apps)
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
        kubectl delete all --all -n "$namespace"
        launch_projects "$1"
        exit 0
    fi

    if [[ -n "${1:-}" ]]; then
        app="$(basename "$1")"
        init_project "$(basename "$(realpath "$1/../..")")"
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
