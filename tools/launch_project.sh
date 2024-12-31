#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
SORT_APPS_TOOL="$WORKSPACE_FOLDER"/tools/launch-project-utils/sort-apps.sh
APPLY_NAMESPACE_TOOL="$WORKSPACE_FOLDER"/tools/launch-project-utils/apply-namespace.sh
APPLY_MANIFESTS_TOOL="$WORKSPACE_FOLDER"/tools/launch-project-utils/apply-manifests.sh
ERROR_LOG="$(mktemp)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

echo_errors_on_exit1() {
    if [ "$?" -eq 1 ]; then
        echo "Script exited with code 1."
        echo "Error logs available $ERROR_LOG"
        exit 1
    fi
}

build_and_apply() {
    "$WORKSPACE_FOLDER"/tools/launch-project-utils/build-docker-images-for-app.sh \
        "$PWD/$1" \
        "$RESOLVE_HELM_TEMPLATE_TOOL" \
        "$SYMLINK_TOOL" \
        "$ERROR_LOG"
    "$APPLY_MANIFESTS_TOOL" "$PWD/$1" "$RESOLVE_HELM_TEMPLATE_TOOL"
}

deploy_cronjobs() {
    mapfile -t JOB_NAMES < "$("$SORT_APPS_TOOL" "$PWD")"
    for job in "${JOB_NAMES[@]}"; do
        build_and_apply "$job"
        kubectl create job --from=cronjob/"${job}" "${job}"-run
        kubectl wait --all --for=condition=Complete --timeout=60s job -l job="${job}"
        kubectl logs -l job="${job}"
    done
}

deploy_apps() {
    mapfile -t APP_NAMES < "$("$SORT_APPS_TOOL" "$PWD")"
    for app in "${APP_NAMES[@]}"; do
        build_and_apply "$app"
        "$WORKSPACE_FOLDER"/tools/launch-project-utils/wait-for-pod.sh "$app"
    done
}

launch_projects() {
    if [[ "${1:-}" == "$(basename "${PROJECT_FOLDER}")" ]]; then
        (cd "${PROJECT_COMMON_FOLDER}"/databases && deploy_apps)
        (cd "${PROJECT_FOLDER}"/initjobs && deploy_cronjobs)
        (cd "${PROJECT_FOLDER}"/apps && deploy_apps)
        (cd "${PROJECT_FOLDER}"/postjobs && deploy_cronjobs)
    elif [[ "${1:-}" == "$(basename "${PROJECT_OTHER_FOLDER}")" ]]; then
        (cd "${PROJECT_COMMON_FOLDER}"/databases && deploy_apps) # Re-use
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

    trap echo_errors_on_exit1 EXIT

    # Deploy project
    if [[ "${1}" == "$(basename "${PROJECT_FOLDER}")" || "${1}" == "$(basename "${PROJECT_OTHER_FOLDER}")" ]]; then
        namespace="$("$APPLY_NAMESPACE_TOOL" "$1" "$VERSION_BRANCH" "$ERROR_LOG")"
        kubectl delete all --all -n "$namespace"
        launch_projects "$1"
        exit 0
    fi

    # Deploy single app
    if [[ -n "${1:-}" ]]; then
        app="$(basename "$1")"
        project="$(basename "$(realpath "$1/../..")")"
        namespace="$("$APPLY_NAMESPACE_TOOL" "$project" "$VERSION_BRANCH" "$ERROR_LOG")"
        cd "${WORKSPACE_FOLDER}/$1/.."
        if ! build_and_apply "$app"; then
            echo "Error: Failed to deploy $1" >&2
            echo "Trying to only apply manifests..." >&2
            "$APPLY_MANIFESTS_TOOL" "$PWD/$1" "$RESOLVE_HELM_TEMPLATE_TOOL"
        fi
        sleep 1
        kubectl delete --now=true pod -l app="$app"
        wait_for_pod "$app"
    fi
}

main "$1"
