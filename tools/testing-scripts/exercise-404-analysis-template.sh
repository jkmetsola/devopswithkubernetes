#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

TEMP_REPODIR="$(create_temp_repodir)"
PROJECT="$(basename "$PROJECT_FOLDER")"
APP_NAME=frontend
APP_REL_PATH=project/apps/$APP_NAME


NAMESPACE="$($APPLY_NAMESPACE_TOOL "$PROJECT" "$VERSION_BRANCH")"
ANALYSIS_TEMPLATE=$APP_REL_PATH/manifests/templates/analysistemplate.yaml
LAUNCH_FRONTEND="$LAUNCH_SINGLE_APP $APP_REL_PATH"
WAIT_ANALYSIS_STATUS=tools/testing-utils/wait-analysis-status.sh
WAIT_PODS_REMOVED=tools/testing-utils/wait-pods-removed.sh

knife_custom_analysis_template(){
    echo "
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: cpu-usage
spec:
  metrics:
  - name: cpu-usage
    initialDelay: 40s
    successCondition: result < $1
    provider:
      prometheus:
        address: http://prometheus-kube-prometheus-prometheus.prometheus.svc.cluster.local:9090
        query: |
          scalar(
            sum(
              rate(
                  container_cpu_usage_seconds_total{namespace=\"$NAMESPACE\"}[40s]
              )
            )
          )
" > "$TEMP_REPODIR/$ANALYSIS_TEMPLATE"
}

launch_frontend_at_new_revision() {
    $START_AND_WAIT_SUBPROCESSES "cd $TEMP_REPODIR && \
        chmod -x .git/hooks/post-commit && \
        git config advice.ignoredHook false && \
        git add $ANALYSIS_TEMPLATE && \
        git commit -m test --no-verify && \
        $LAUNCH_FRONTEND"
}

remove_rollout_and_wait_pods_are_removed(){
  kubectl delete --ignore-not-found --wait rollout "$APP_NAME" -n "$NAMESPACE"
  timeout --verbose 10 $WAIT_PODS_REMOVED "$APP_NAME" "$NAMESPACE"
}

execute_analysis_test(){
  remove_rollout_and_wait_pods_are_removed
  $START_AND_WAIT_SUBPROCESSES "cd $TEMP_REPODIR && $LAUNCH_FRONTEND"

  knife_custom_analysis_template "$3"
  launch_frontend_at_new_revision
  timeout --verbose 60 $WAIT_ANALYSIS_STATUS "$1" "$2" "$NAMESPACE" "$APP_NAME"
}

# Phase 1: Failing analysis
execute_analysis_test "Failed" "Degraded" 0.0001

# Phase 2: Passing analysis
TEMP_REPODIR="$(create_temp_repodir)"
execute_analysis_test "Successful" "Healthy" 0.03

# Phase 3: Cleanup
TEMP_REPODIR="$(create_temp_repodir)"
remove_rollout_and_wait_pods_are_removed
$START_AND_WAIT_SUBPROCESSES "cd $TEMP_REPODIR && $LAUNCH_FRONTEND"
