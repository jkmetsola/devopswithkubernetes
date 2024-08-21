#!/bin/bash
set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
DOTENV_PATH="${WORKSPACE_FOLDER}"/.env

configure_dotenv() {
  if [ ! -f "$DOTENV_PATH" ]; then
      echo ".env file does not exist. Asking git variables"
      echo -n "Enter git username: " && read -r GIT_USER
      echo -n "Enter git email: " && read -r GIT_EMAIL
  fi
  touch "$DOTENV_PATH"
  # shellcheck source=.env
  . "${DOTENV_PATH}"
  {
    echo "GIT_USER=$GIT_USER"
    echo "GIT_EMAIL=$GIT_EMAIL"
    echo "SETUP_ENV_PATH=$WORKSPACE_FOLDER/.devcontainer/setupEnv.sh"
  } > "$DOTENV_PATH"
}

configure_dotenv
# shellcheck source=.env
. "${DOTENV_PATH}"
