#!/bin/bash
set -euo pipefail

EXECUTABLE_SCRIPT="$1"
EXECUTABLE_SCRIPT_ARG="$2"
CONFIGURE_DEVUSER="$3"
DEVUSER="$4"
HOST_UID="$5"
HOST_GID="$6"
HOST_DOCKER_GID="$7"

configure_user() {
  apt-get update
  apt-get install sudo
  ${CONFIGURE_DEVUSER} "$DEVUSER" "$HOST_UID" "$HOST_GID" "$HOST_DOCKER_GID"
}

configure_user
su -c "$EXECUTABLE_SCRIPT $EXECUTABLE_SCRIPT_ARG" "$DEVUSER"
