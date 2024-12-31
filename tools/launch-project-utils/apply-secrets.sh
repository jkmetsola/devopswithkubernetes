#!/bin/bash

set -euo pipefail

APP_DIR=$1

apply_secrets() {
    secrets_file="$APP_DIR/manifests/secret.enc.yaml"
    secrets_file_decrypted="$APP_DIR/manifests/secret.yaml"
    if [[ -f "$secrets_file" ]]; then
        if [[ -f "$secrets_file_decrypted" && "$secrets_file" -ot "$secrets_file_decrypted" ]]; then
            "$AGE_KEY_TOOL" "$secrets_file_decrypted"
        fi
        "$AGE_KEY_TOOL" "$secrets_file" | kubectl apply -f -
    fi
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi

apply_secrets
