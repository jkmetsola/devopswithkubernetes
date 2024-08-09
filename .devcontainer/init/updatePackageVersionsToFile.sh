#!/bin/bash
set -euo pipefail

package_file="$1"
installed_packages_list="$2"
tmp_package_file="${package_file}_tmp"

cp "$package_file" "$tmp_package_file"
trap 'rm -f "$tmp_package_file"' EXIT

if ! .devcontainer/shellTools/checkLineFeed.sh "$package_file"; then
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
    sed -i "/$line/c\\$new_line" "${1}_tmp"
  fi
done < "$package_file"

mv "$tmp_package_file" "$package_file"
