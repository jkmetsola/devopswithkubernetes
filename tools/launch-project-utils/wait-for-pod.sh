#!/bin/bash

set -euo pipefail

APP=$1

wait_for_pod() {
    kubectl wait --all --for=condition=Ready --timeout=60s pod -l app="$APP"
    kubectl logs --all-containers -l app="$APP"
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi
wait_for_pod
