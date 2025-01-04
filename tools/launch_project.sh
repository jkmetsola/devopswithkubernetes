#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
SORT_APPS_TOOL="$WORKSPACE_FOLDER"/tools/launch-project-utils/sort-apps.sh
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_ARG="$1"

echo_errors_on_exit1() {
    if [ "$?" -eq 1 ]; then
        echo "Script '$SCRIPT_NAME $SCRIPT_ARG' exited with code 1." >&2
        echo "Error logs available $ERROR_LOG" >&2
        echo "temp repodir: $TEMP_REPODIR" >&2
        exit 1
    fi
    rm -rf "$TEMP_REPODIR"
}

build_and_apply() {
    $BUILD_AND_APPLY_TOOL "$1" "$NAMESPACE"
}

deploy_cronjobs() {
    job_parent_dir=$1
    mapfile -t JOB_NAMES < "$("$SORT_APPS_TOOL" "$job_parent_dir")"
    for job in "${JOB_NAMES[@]}"; do
        build_and_apply "$job_parent_dir/$job"
        kubectl create job --namespace "$NAMESPACE" --from=cronjob/"${job}" "${job}"-run
        kubectl wait --namespace "$NAMESPACE" --all --for=condition=Complete --timeout=60s job -l job="${job}"
        kubectl logs --namespace "$NAMESPACE" -l job="${job}"
    done
}

deploy_apps() {
    app_parent_dir=$1
    mapfile -t APP_NAMES < "$("$SORT_APPS_TOOL" "$app_parent_dir")"
    for app in "${APP_NAMES[@]}"; do
        build_and_apply "$app_parent_dir/$app"
        $WAIT_FOR_POD_TOOL "$app" "$NAMESPACE"
    done
}

launch_projects() {
    TEMP_REPODIR="$(mktemp --directory)/$(basename "$WORKSPACE_FOLDER")"
    cp -r "$WORKSPACE_FOLDER" "$TEMP_REPODIR"
    temp_project_common_dir="$TEMP_REPODIR"/"$(basename "$PROJECT_COMMON_FOLDER")"
    temp_project_dir="$TEMP_REPODIR"/"$(basename "$PROJECT_FOLDER")"
    temp_project_other_dir="$TEMP_REPODIR"/"$(basename "$PROJECT_OTHER_FOLDER")"
    if [[ "${1:-}" == "$(basename "${PROJECT_FOLDER}")" ]]; then
        deploy_apps "${temp_project_common_dir}"/databases
        deploy_cronjobs "${temp_project_dir}"/initjobs
        deploy_apps "${temp_project_dir}"/apps
        deploy_cronjobs "${temp_project_dir}"/postjobs
    elif [[ "${1:-}" == "$(basename "${PROJECT_OTHER_FOLDER}")" ]]; then
        deploy_apps "${temp_project_common_dir}"/databases # Re-use
        deploy_apps "${temp_project_other_dir}"/apps
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
    NAMESPACE="$("$APPLY_NAMESPACE_TOOL" "$1" "$VERSION_BRANCH" "$ERROR_LOG")"
    kubectl delete all --all -n "$NAMESPACE"
    launch_projects "$1"
}

main "$1"
