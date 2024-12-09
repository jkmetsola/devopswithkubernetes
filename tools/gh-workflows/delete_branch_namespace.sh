#!/bin/bash

set -euo pipefail

project_name="$1"

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

kubectl delete namespace "$project_name"-"$VERSION_BRANCH"
