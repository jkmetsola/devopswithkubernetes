#!/bin/bash
set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
IMAGE_CACHE=jkmetsola/dwk-deploy:buildcache
if [[ "${EXPORT_IMAGE_CACHE:-}" = "true" ]]; then
  CACHE_EXPORT_FLAG="--builder=mybuilder --cache-to=type=registry,ref=$IMAGE_CACHE,mode=max "
fi

update_linux_package_versions() {
  docker run --rm \
    -w "${WORKSPACE_FOLDER}" \
    -v "${WORKSPACE_FOLDER}:${WORKSPACE_FOLDER}" \
    "$BASE_IMAGE" \
    ".devcontainer/init/runAsUser.sh" \
    "${UPDATE_LINUX_PKG_SCRIPT}" "${SETUP_ENV_PATH}" \
    "${CONFIGURE_DEVUSER}" "${DEVUSER}" "${HOST_UID}" "${HOST_GID}" "${HOST_DOCKER_GID}"
}

setup_env(){
  if [ "$(whoami)" != "devroot" ]; then
  # shellcheck source=.devcontainer/setupEnv.sh
  source "$SETUP_ENV_PATH" "false" # Don't modify devcontainer json
  else
  # shellcheck source=.devcontainer/setupEnv.sh
    source "$SETUP_ENV_PATH" "true"
  fi
}

perform_package_updates_if_needed(){
  set -x
  # No space after CACHE_EXPORT_FLAG is with intention.
  test_devenv_build_cmd="$(xargs -a "${TEMP_BUILDARG_FILE}" -I {} echo \
      docker buildx build {} \
      --cache-from=type=registry,ref=$IMAGE_CACHE \
      "${CACHE_EXPORT_FLAG:-}"\
      -t "$1" \
      "$WORKSPACE_FOLDER")"
  set +x
  if ! eval "$test_devenv_build_cmd" ; then
    echo "Updating linux package versions to files..."
    update_linux_package_versions
  fi
}

source "$WORKSPACE_FOLDER"/.devcontainer/configureDotEnv.sh
setup_env
perform_package_updates_if_needed "${1:-jkmetsola/dwk-deploy:latest}"
echo "Initialisation complete."
