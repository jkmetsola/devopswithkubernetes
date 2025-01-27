#!/bin/bash

set -euo pipefail

ANALYSIS_STATUS=$1
ROLLOUT_STATUS=$2
NAMESPACE=$3
APP_NAME=$4

cleanup() {
    echo ""
    check_analysis_status
}

check_analysis_status(){
    latest_analysis_run="$(\
      kubectl get ar --namespace "$NAMESPACE" \
        --sort-by=.metadata.creationTimestamp \
        -o jsonpath='{.items[-1].metadata.name}'\
    )"
    analysis_status="$(\
      kubectl get ar "$latest_analysis_run" --namespace "$NAMESPACE" \
        -o jsonpath='{.status.phase}'
    )"
    rollout_status="$(kubectl get ro/"$APP_NAME" -o jsonpath='{.status.phase}')"
    $START_AND_WAIT_SUBPROCESSES \
      "kubectl argo rollouts get rollout $APP_NAME --namespace $NAMESPACE" \
      "[[ $analysis_status == $ANALYSIS_STATUS ]]" \
      "[[ $rollout_status == $ROLLOUT_STATUS ]]"
}

wait_for_status(){
  echo -n "Checking analysis status ."
  while ! check_analysis_status > /dev/null 2>&1; do
    echo -n "."
    sleep 3
  done
}

trap cleanup EXIT
wait_for_status
