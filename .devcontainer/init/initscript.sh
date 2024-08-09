#!/bin/bash
set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

configure_dotenv() {
  if [ ! -f .env ]; then
      echo ".env file does not exist. Creating one now."
      echo -n "Enter git username: " && read -r git_user
      echo "GIT_USER=$git_user" >> .env
      echo -n "Enter git email: " && read -r git_email
      echo "GIT_EMAIL=$git_email" >> .env
      echo ".env file created with git variables."

  else
      echo ".env file already exists. Skipping initialization of git variables."
  fi
}


update_linux_package_versions() {
  local linux_dev_env_pkg_file="$WORKSPACE_FOLDER"/$IMAGEFILES_DIR/"$PACKAGES_DEVENV_FILENAME"
  local linux_dev_lint_pkg_file="$WORKSPACE_FOLDER"/$IMAGEFILES_DIR/"$PACKAGES_DEVLINT_FILENAME"
  local packages_to_install
  local installed_packages_list
  packages_to_install=$(cat "$linux_dev_lint_pkg_file" "$linux_dev_env_pkg_file" | xargs -n 1 echo | cut -d'=' -f1) # Get package names without version
  installed_packages_list=$(docker run --rm \
    -v "$WORKSPACE_FOLDER/.devcontainer/init/packageInstallAndList.sh:/tmp/packageInstallAndList.sh" \
    "$BASE_IMAGE" /tmp/packageInstallAndList.sh "$packages_to_install")
  "$WORKSPACE_FOLDER"/.devcontainer/init/updatePackageVersionsToFile.sh "$linux_dev_lint_pkg_file" "$installed_packages_list"
  "$WORKSPACE_FOLDER"/.devcontainer/init/updatePackageVersionsToFile.sh "$linux_dev_env_pkg_file" "$installed_packages_list"
}

configure_dotenv
if [ "$(whoami)" != "devroot" ]; then
  source "$WORKSPACE_FOLDER"/.devcontainer/setupEnv.sh "false" # Don't modify devcontainer.json
else
  source "$WORKSPACE_FOLDER"/.devcontainer/setupEnv.sh "true"
fi
set -x
test_devenv_build_cmd="$(xargs -a "${TEMP_BUILDARG_FILE}" -I {} echo docker build {} -t dev-env-test "$WORKSPACE_FOLDER")"
set +x
if ! eval "$test_devenv_build_cmd" ; then
  echo "Updating linux package versions to files..."
  update_linux_package_versions
fi
echo "Initialisation complete."
