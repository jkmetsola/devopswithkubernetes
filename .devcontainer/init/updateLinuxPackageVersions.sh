#!/bin/bash
set -euo pipefail

update_versions_to_file(){
  local package_file="$1"
  local installed_packages_list="$2"
  TMP_PACKAGE_FILE=$(mktemp)

  cp "$package_file" "$TMP_PACKAGE_FILE"
  trap 'rm -f "$TMP_PACKAGE_FILE"' EXIT

  if ! "${CHECK_LINEFEED}" "$package_file"; then
    echo "" >> "$1"
    echo -e "\033[0;31mLast byte was not line feed in $package_file. Linefeed inserted. Please re-run.\033[0m"
    exit 1
  fi

  while IFS= read -r line; do
    package_name=$(echo "$line" | cut -d'=' -f1)
    echo "Checking $package_name"
    if ! echo "$installed_packages_list" | grep -qx "$line"; then
      echo "Package $line not found in installed packages list. Trying to update..."
      new_line="$(echo "$installed_packages_list" | grep "^$package_name=")"
      echo "Updating $line to $new_line"
      sed -i "/$line/c\\$new_line" "$TMP_PACKAGE_FILE"
    fi
  done < "$package_file"
  cat "$TMP_PACKAGE_FILE" > "$package_file"
}

package_install_and_list() {
  {
      sudo apt-get update
      set -x
      echo "$@" | xargs sudo apt-get install --no-install-recommends -y
      set +x
  } > /dev/null
  dpkg -l | awk '/^ii/{print $2 "=" $3}'
}




# shellcheck source=.devcontainer/setupEnv.sh
source "$1" "false"
sudo "$REPOS_DEVENV"
PACKAGES_TO_INSTALL=$(cat "$PACKAGES_DEVLINT" "$PACKAGES_DEVENV" | xargs -n 1 echo | cut -d'=' -f1) # Get package names without version
INSTALLED_PACKAGES_LIST=$(package_install_and_list "$PACKAGES_TO_INSTALL")
update_versions_to_file "$PACKAGES_DEVENV" "$INSTALLED_PACKAGES_LIST"
update_versions_to_file "$PACKAGES_DEVLINT" "$INSTALLED_PACKAGES_LIST"
