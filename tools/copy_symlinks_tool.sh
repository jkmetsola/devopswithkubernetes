#!/bin/bash

set -euo pipefail

copy_symlinks_in_folder() {
    find . -mindepth 1 -maxdepth 1 -type l | while read -r symlink; do
        target=$(readlink "$symlink")
        cp "$target" "$1/$(basename "${symlink%.symlink}")"
    done
}

main() {
    if [[ -n "${DEBUG:-}" ]]; then
        set -x
        export DEBUG
    fi
    (cd "$1" && copy_symlinks_in_folder "$1")
}

main "$1"
