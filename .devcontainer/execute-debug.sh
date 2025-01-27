#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

STDERR_TO_FILE=true $START_AND_WAIT_SUBPROCESSES \
    "BASH_ENV=$WORKSPACE_FOLDER/.devcontainer/enable-debug.sh $1"
