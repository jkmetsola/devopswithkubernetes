#!/bin/bash

set -euo pipefail

PROJECT=$1
VERSION_BRANCH=$2

main() {
    if [[ $VERSION_BRANCH = "main" && "$PROJECT" = "project" ]]; then
        namespace="default"
    else
        namespace="$PROJECT-$VERSION_BRANCH"
    fi
    (kubectl create namespace "$namespace" || kubectl get namespace "$namespace") > /dev/null 2> "$ERROR_LOG"
    # kubectl config set-context --current --namespace="$namespace" > /dev/null
    echo "$namespace"
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi

main
