#!/bin/bash
set -euo pipefail

DEVUSER=$1
HOST_UID=$2
HOST_GID=$3
HOST_DOCKER_GID=$4

if ! getent group "$HOST_GID" > /dev/null; then
    groupadd -g "$HOST_GID" user_host
fi
useradd -s /bin/bash -mlou "$HOST_UID" -g "$HOST_GID" "$DEVUSER" && \
echo "$DEVUSER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \

if ! getent group "$HOST_DOCKER_GID" > /dev/null; then
    groupadd -g "$HOST_DOCKER_GID" docker_host
fi
usermod -aG "$(getent group "$HOST_DOCKER_GID" | cut -d: -f1)" "$DEVUSER"
