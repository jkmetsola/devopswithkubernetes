#!/bin/bash

set -euo pipefail

JOBS_DIR=$1
NAMESPACE=$2

deploy_cronjobs() {
    mapfile -t JOB_NAMES < <($GET_BASENAMES_TOOL "$JOBS_DIR")
    for job in "${JOB_NAMES[@]}"; do
        JOB_DIR=$JOBS_DIR/$job
        COMMANDS+=(
            "$BUILD_AND_APPLY_TOOL $JOB_DIR $NAMESPACE && \
            kubectl create job --namespace $NAMESPACE --from=cronjob/${job} ${job}-run && \
            kubectl wait --namespace $NAMESPACE --all --for=condition=Complete --timeout=90s job -l job=${job} && \
            kubectl logs --namespace $NAMESPACE --all-containers -l job=${job}"
        )
    done
    $START_AND_WAIT_SUBPROCESSES "${COMMANDS[@]}"
}

main() {
    deploy_cronjobs
}

main
