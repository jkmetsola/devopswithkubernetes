#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER"/.env

cat "${WORKSPACE_FOLDER}/.devcontainer/bashrc-custompart.sh" >> ~/.bashrc
echo "
git config --global user.email \"$GIT_EMAIL\"
git config --global user.name \"$GIT_USER\"
git config --global pager.diff true
" >> ~/.bashrc

cp .devcontainer/git-hooks/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
