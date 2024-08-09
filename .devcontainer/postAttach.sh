#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

source "${WORKSPACE_FOLDER}"/.devcontainer/setupEnv.sh "false"

pip-compile -U --no-strip-extras "${WORKSPACE_FOLDER}"/"${IMAGEFILES_DIR}"/requirements.in > /dev/null 2>&1
pip-compile -U --no-strip-extras "${WORKSPACE_FOLDER}"/"${IMAGEFILES_DIR}"/requirements-dev.in > /dev/null 2>&1