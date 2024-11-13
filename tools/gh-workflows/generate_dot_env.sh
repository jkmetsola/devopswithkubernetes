#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

echo "SETUP_ENV_PATH=$WORKSPACE_FOLDER/.devcontainer/setupEnv.sh
GIT_USER=dummy
GIT_EMAIL=dummy
" > .env
