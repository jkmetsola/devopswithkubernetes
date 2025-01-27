#!/bin/bash

set -euo pipefail

APP_NAME=$1
NAMESPACE=$2

check_pods(){
    kubectl get pods -n "$NAMESPACE" -l "app=$APP_NAME" --no-headers
}

cleanup(){
    check_pods
}

main(){
    echo -n "Waiting $APP_NAME pods to be removed "
    trap cleanup EXIT
    while [[ "$(check_pods | wc -l)" != "0" ]]; do
        echo -n "."
        sleep 1
    done
}

main
