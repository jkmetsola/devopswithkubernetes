#!/bin/bash

set -euo pipefail

DIRECTORY=$1

get_basenames(){
    find "$DIRECTORY" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
}

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    export DEBUG
fi
get_basenames
