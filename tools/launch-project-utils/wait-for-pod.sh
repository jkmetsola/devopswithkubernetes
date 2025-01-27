#!/bin/bash

set -euo pipefail

APP=$1
NAMESPACE=$2

wait_for_pod() {
    kubectl wait --namespace "$NAMESPACE" --all --for=condition=Ready --timeout=10s pod -l app="$APP"
    kubectl logs --namespace "$NAMESPACE" --all-containers -l app="$APP"
}

cleanup(){
    wait_for_pod
}

main(){
    echo -n "Waiting for pods to be available ."
    trap cleanup EXIT
    while ! wait_for_pod > /dev/null 2>&1; do
        echo -n "."
        sleep 1
    done
}

main
