#!/bin/bash

set -euo pipefail

JOBS_DIR=$1
NAMESPACE=$2

DEPLOYMENT_PIDS=()

wait_for_deployment_pids(){
    for deployment_pid in "${DEPLOYMENT_PIDS[@]}"; do
        wait "$deployment_pid"
    done
}

deploy_cronjobs() {
    mapfile -t JOB_NAMES < <($GET_BASENAMES_TOOL "$JOBS_DIR")
    for job in "${JOB_NAMES[@]}"; do
        temp_job_log="$(mktemp)"
        echo "Outputting $job job logs to $temp_job_log"
        (
            $BUILD_AND_APPLY_TOOL "$JOBS_DIR/$job" "$NAMESPACE"
            kubectl create job --namespace "$NAMESPACE" --from=cronjob/"${job}" "${job}"-run
            kubectl wait --namespace "$NAMESPACE" --all --for=condition=Complete --timeout=90s job -l job="${job}"
            kubectl logs --namespace "$NAMESPACE" --all-containers -l job="${job}"
        ) > "$temp_job_log" &
        DEPLOYMENT_PIDS+=($!)
    done
    wait_for_deployment_pids
}

main() {
    if [[ -n "${DEBUG:-}" ]]; then
        set -x
        export DEBUG
    fi
    deploy_cronjobs
}

main
