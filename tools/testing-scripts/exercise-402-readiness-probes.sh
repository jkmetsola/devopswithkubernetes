#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"
NAMESPACE="$("$APPLY_NAMESPACE_TOOL" "project" "$VERSION_BRANCH" "$ERROR_LOG")"
TEMP_REPODIR="$(create_temp_repodir)"
TEMP_LOGS="$(mktemp)"

launch_backend_and_print_status() {
    echo "Launching app, logs available $TEMP_LOGS"
    (
        cd "$TEMP_REPODIR"
        $LAUNCH_SINGLE_APP project/apps/backend
    ) >> "$TEMP_LOGS" || true
    kubectl get po --namespace "$NAMESPACE"
}

knife_wrong_db_url() {
    knifed_values="$TEMP_REPODIR"/project/apps/backend/manifests/values.yaml
    echo "Knifing wrong database url under $knifed_values"
    echo "
---
containerNames:
  - backend
  - backend-debug
serviceName: backend-svc
clusterPort: 1015
appPort: 3015
dbTableName: todos
databases:
  postgres:
    serviceName: google.com
    appPort: 80
    containerNames:
      - postgres
" > "$knifed_values"
}

main() {
    launch_backend_and_print_status
    knife_wrong_db_url
    launch_backend_and_print_status
    TEMP_REPODIR="$(create_temp_repodir)"
    launch_backend_and_print_status
}

main
