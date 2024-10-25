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
  export UPDATE_LINUX_PKG_SCRIPT=${WORKSPACE_FOLDER}/.devcontainer/init/updateLinuxPackageVersions.sh
  export EXECUTE_WITH_USER=${WORKSPACE_FOLDER}/.devcontainer/init/executeWithUser.sh
  export DEVCONTAINER_JSON=${WORKSPACE_FOLDER}/.devcontainer/devcontainer.json
  export CHECK_LINEFEED=${WORKSPACE_FOLDER}/.devcontainer/shellTools/checkLineFeed.sh
  export REPOS_DEVENV=${WORKSPACE_FOLDER}/${REPOS_DEVENV_FILE}
  export PACKAGES_DEVENV=${WORKSPACE_FOLDER}/${PACKAGES_DEVENV_FILE}
  export PACKAGES_DEVLINT=${WORKSPACE_FOLDER}/${PACKAGES_DEVLINT_FILE}
  export CONFIGURE_DEVUSER=${WORKSPACE_FOLDER}/${CONFIGURE_DEVUSER_FILE}
  export RESOLVE_HELM_TEMPLATE_TOOL=${WORKSPACE_FOLDER}/tools/resolve_helm_template.sh
  export PROJECT_FOLDER=${WORKSPACE_FOLDER}/project
  export PROJECT_OTHER_FOLDER=${WORKSPACE_FOLDER}/project-other
  export BASE_TEMPLATES_FOLDER=${WORKSPACE_FOLDER}/base_templates
  export SYMLINK_TOOL=${WORKSPACE_FOLDER}/tools/copy_symlinks_tool.sh
  export AGE_KEY_TOOL=${WORKSPACE_FOLDER}/tools/age_key_tool.sh
  export LAUNCH_PROJECT=${WORKSPACE_FOLDER}/tools/launch_project.sh
}
export CONFIGURE_DEVCONTAINER_JSON=${WORKSPACE_FOLDER}/.devcontainer/configure_devcontainer_json.py
configure_devcontainer_json "$1"
# shellcheck disable=SC1090
. "$TEMP_BUILD_ENV_FILE"
define_global_vars
