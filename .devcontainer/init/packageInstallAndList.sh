#!/bin/bash
set -euo pipefail
{
    apt-get update
    set -x
    echo "$@" | xargs apt-get install --no-install-recommends -y
    set +x
} > /dev/null



dpkg -l | awk '/^ii/{print $2 "=" $3}'