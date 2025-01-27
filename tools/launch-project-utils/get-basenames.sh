#!/bin/bash

set -euo pipefail

DIRECTORY=$1

get_basenames(){
    find "$DIRECTORY" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
}

get_basenames
