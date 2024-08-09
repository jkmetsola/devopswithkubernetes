#!/bin/bash

set -euo pipefail

if [ "$(tail -c 1 "$1" | od -An -tx1)" != " 0a" ]; then
    echo -e "\033[0;31m$1: No new line at the end of the file.\033[0m"
    exit 1
fi
