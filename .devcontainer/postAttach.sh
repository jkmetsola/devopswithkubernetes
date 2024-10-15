#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.devcontainer/setupEnv.sh
source "$WORKSPACE_FOLDER"/.devcontainer/configureDotEnv.sh

# shellcheck source=.devcontainer/setupEnv.sh
source "$SETUP_ENV_PATH" "false"

pip-compile -U --no-strip-extras "${WORKSPACE_FOLDER}"/imagefiles/requirements.in > /dev/null 2>&1
pip-compile -U --no-strip-extras "${WORKSPACE_FOLDER}"/imagefiles/requirements-dev.in > /dev/null 2>&1
