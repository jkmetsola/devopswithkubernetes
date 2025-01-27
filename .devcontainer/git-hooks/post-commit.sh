#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

output_information_and_sleep(){
    git log -1
    echo ""
    echo "Commit succesful. Executing local tests after 10s."
    sleep 10
}

clean_workspace(){
    temp_env="$(mktemp)"
    cp "$WORKSPACE_FOLDER"/.env "$temp_env"
    output="$(git clean -f -X)"
    echo "$output" | grep -v "Removing .env" || true
    cp "$temp_env" "$WORKSPACE_FOLDER"/.env
}

if [ -d "$WORKSPACE_FOLDER/.git/rebase-merge" ] || [ -d "$WORKSPACE_FOLDER/.git/rebase-apply" ]; then
    echo "Rebase in progress. Skipping post-commit actions."
    exit 0
fi

if [[ -z "${SKIP_MSG:-}" ]]; then
    output_information_and_sleep
fi

NAMESPACE="$("$APPLY_NAMESPACE_TOOL" "project" "$VERSION_BRANCH" "$ERROR_LOG")"

clean_workspace

kubectl config use-context k3d-k3s-default

$START_AND_WAIT_SUBPROCESSES \
    "cd $(create_temp_repodir) && $LAUNCH_PROJECT project" \
    "cd $(create_temp_repodir) && $LAUNCH_PROJECT project-other"

$START_AND_WAIT_SUBPROCESSES \
    "tools/testing-scripts/test-sending-many-requests.sh frontend $NAMESPACE"

$START_AND_WAIT_SUBPROCESSES \
    "tools/testing-scripts/exercise-401-readiness-probes.sh" \
    "tools/testing-scripts/exercise-402-readiness-probes.sh"

$START_AND_WAIT_SUBPROCESSES \
    "tools/testing-scripts/exercise-404-analysis-template.sh"
