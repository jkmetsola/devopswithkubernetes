#!/bin/bash

set -euo pipefail

APP=$1
NAMESPACE=$2

wait_for_pod() {
    kubectl wait --namespace "$NAMESPACE" --all --for=condition=Ready --timeout=90s pod -l app="$APP"
    kubectl logs --namespace "$NAMESPACE" --all-containers -l app="$APP"
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi
wait_for_pod
