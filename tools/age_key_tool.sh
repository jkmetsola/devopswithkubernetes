#!/bin/bash

# Useful command to convert yaml data values to base64:
# yq eval -i '.data |= with_entries(.value |= @base64)' $secret_file

set -euo pipefail

export SOPS_AGE_KEY_FILE=~/.age/key

generate_key() {
    age-keygen -o $SOPS_AGE_KEY_FILE
}

public_key() {
    age-keygen -y $SOPS_AGE_KEY_FILE
}

if [ ! -f "$SOPS_AGE_KEY_FILE" ]; then
    echo "Key is not generated."
    generate_key
    echo "Key generated to \"$SOPS_AGE_KEY_FILE\""
    exit 1
else
    if [[ "${1:-}" == *.enc.yaml ]]; then
        sops --decrypt "$1"
    elif [[ "${1:-}" == *.yaml ]]; then
        encrypted_file="$(dirname "$1")"/"$(basename --suffix .yaml "$1" )".enc.yaml
        sops --encrypt --age "$(public_key)" "$1"  > "$encrypted_file"
    fi
fi
