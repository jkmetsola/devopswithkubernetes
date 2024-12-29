#!/bin/bash

set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER"/.env



curl -o ~/git-prompt.sh \
    https://raw.githubusercontent.com/git/git/refs/heads/master/contrib/completion/git-prompt.sh
cat "${WORKSPACE_FOLDER}/.devcontainer/bashrc-custompart.sh" >> ~/.bashrc
echo "
git config --global user.email \"$GIT_EMAIL\"
git config --global user.name \"$GIT_USER\"
git config --global pager.diff true
" >> ~/.bashrc

cp .devcontainer/git-hooks/pre-commit.sh .git/hooks/pre-commit
cp .devcontainer/git-hooks/post-commit.sh .git/hooks/post-commit
chmod +x .git/hooks/pre-commit .git/hooks/post-commit
