#!/bin/bash
set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

if getent group docker > /dev/null; then
  DOCKER_GID="$(getent group docker | cut -d: -f3)"
else
  DOCKER_GID="$(getent group docker_host | cut -d: -f3)"
fi

configure_devcontainer_json() {
    TEMP_BUILD_ENV_FILE=$(mktemp)
    TEMP_BUILDARG_FILE=$(mktemp)
    cleanup() {
        rm -f "$TEMP_BUILD_ENV_FILE" "$TEMP_BUILDARG_FILE"
    }
    trap 'cleanup' EXIT
    "$CONFIGURE_DEVCONTAINER_JSON" \
        --host-docker-gid "$DOCKER_GID" \
        --host-uid "$(id -u)" \
        --host-gid "$(id -g)" \
        --build-arg-output-file "${TEMP_BUILDARG_FILE}" \
        --build-env-output-file "${TEMP_BUILD_ENV_FILE}" \
        --modify-devcontainer-json "$1"
}

define_global_vars(){
  ERROR_LOG="$(mktemp)"
  GIT_BRANCH="${GITHUB_EVENT_REF:-"$(git rev-parse --abbrev-ref HEAD)"}"
  PROJECT_ID="$(gcloud config list --format='value(core.project)')" || true
  VERSION_BRANCH="$(echo "$GIT_BRANCH" | tr '/' '-')"
  VERSION_TAG="$VERSION_BRANCH-$(git rev-parse HEAD)"
  export AGE_KEY_TOOL=${WORKSPACE_FOLDER}/tools/age_key_tool.sh
  export APPLY_MANIFESTS_TOOL=${WORKSPACE_FOLDER}/tools/launch-project-utils/apply-manifests.sh
  export APPLY_NAMESPACE_TOOL=${WORKSPACE_FOLDER}/tools/launch-project-utils/apply-namespace.sh
  export BASE_TEMPLATES_DIR=${WORKSPACE_FOLDER}/base_templates/partial_templates
  export BASE_TEMPLATES_FOLDER=${WORKSPACE_FOLDER}/base_templates
  export BUILD_AND_APPLY_TOOL=${WORKSPACE_FOLDER}/tools/launch-project-utils/build-and-apply-app.sh
  export CHECK_LINEFEED=${WORKSPACE_FOLDER}/.devcontainer/shellTools/checkLineFeed.sh
  export CONFIGURE_DEVUSER=${WORKSPACE_FOLDER}/${CONFIGURE_DEVUSER_FILE}
  export DEVCONTAINER_JSON=${WORKSPACE_FOLDER}/.devcontainer/devcontainer.json
  export ERROR_LOG
  export EXECUTE_WITH_USER=${WORKSPACE_FOLDER}/.devcontainer/init/executeWithUser.sh
  export GET_BASENAMES_TOOL=${WORKSPACE_FOLDER}/tools/launch-project-utils/get-basenames.sh
  export LAUNCH_PROJECT=${WORKSPACE_FOLDER}/tools/launch_project.sh
  export LAUNCH_SINGLE_APP=${WORKSPACE_FOLDER}/tools/launch_single_app.sh
  export PACKAGES_DEVENV=${WORKSPACE_FOLDER}/${PACKAGES_DEVENV_FILE}
  export PACKAGES_DEVLINT=${WORKSPACE_FOLDER}/${PACKAGES_DEVLINT_FILE}
  export PROJECT_COMMON_FOLDER=${WORKSPACE_FOLDER}/project-common
  export PROJECT_FOLDER=${WORKSPACE_FOLDER}/project
  export PROJECT_ID
  export PROJECT_OTHER_FOLDER=${WORKSPACE_FOLDER}/project-other
  export REPOS_DEVENV=${WORKSPACE_FOLDER}/${REPOS_DEVENV_FILE}
  export RESOLVE_HELM_TEMPLATE_TOOL=${WORKSPACE_FOLDER}/tools/resolve_helm_template.sh
  export START_AND_WAIT_SUBPROCESSES=${WORKSPACE_FOLDER}/tools/launch-utils/start-and-wait-subprocesses.sh
  export SYMLINK_TOOL=${WORKSPACE_FOLDER}/tools/copy_symlinks_tool.sh
  export UPDATE_LINUX_PKG_SCRIPT=${WORKSPACE_FOLDER}/.devcontainer/init/updateLinuxPackageVersions.sh
  export VERSION_BRANCH
  export VERSION_TAG
  export WAIT_FOR_POD_TOOL=${WORKSPACE_FOLDER}/tools/launch-project-utils/wait-for-pod.sh
}

create_temp_repodir() {
  temp_repodir="$(mktemp --directory)/$(basename "$WORKSPACE_FOLDER")"
  cp -r "$WORKSPACE_FOLDER" "$temp_repodir"
  echo "$temp_repodir"
}

export CONFIGURE_DEVCONTAINER_JSON=${WORKSPACE_FOLDER}/.devcontainer/configure_devcontainer_json.py
configure_devcontainer_json "$1"
# shellcheck disable=SC1090
. "$TEMP_BUILD_ENV_FILE"
define_global_vars
