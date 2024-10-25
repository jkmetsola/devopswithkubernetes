#!/bin/bash
set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

get_previous_commit_ref() {
    if ps -ocommand= -p $PPID | grep --quiet -e '--amend'; then
        echo "HEAD~1"
    else
        echo "HEAD"
    fi
}

check_usage_of_modified_files() {
    .devcontainer/grep_tool/grep_tool.py \
        --whitelist-file "${WORKSPACE_FOLDER}/.devcontainer/git-hooks/whitelist.json" \
        --previous-commit-sha "$(get_previous_commit_ref)"
}

check_whitespace_error() {
    git diff-index --check --cached HEAD --
}

check_linefeed_eof() {
    git diff-index --cached --name-only --diff-filter=d HEAD \
        | xargs --no-run-if-empty -I {} find {} -type f \
        | xargs -L 1 --no-run-if-empty "${CHECK_LINEFEED}"
}

lint_python_files() {
    grep --null -Rl '^#!/usr/bin/env python3' | xargs -0 ruff check
    grep --null -Rl '^#!/usr/bin/env python3' | xargs -0 ruff format --diff
}

lint_sh_files() {
    find . -type f -name "*.sh" -print0 | xargs -0 shellcheck
}

lint_helm_templates() {
    find "${PROJECT_FOLDER}" -mindepth 2 -maxdepth 2 -type d -print0 \
        | xargs -0 -n 1 "${RESOLVE_HELM_TEMPLATE_TOOL}" \
        | xargs yamllint
    find "${PROJECT_OTHER_FOLDER}" -mindepth 2 -maxdepth 2 -type d -print0 \
        | xargs -0 -n 1 "${RESOLVE_HELM_TEMPLATE_TOOL}" \
        | xargs yamllint
}

lint_other_yaml_files() {
    find "${WORKSPACE_FOLDER}" -type f -name '*.yaml' \
        \( \
        ! -path "${PROJECT_FOLDER}/*" \
        -a \
        ! -path "${PROJECT_OTHER_FOLDER}/*" \
        -a \
        ! -path "${BASE_TEMPLATES_FOLDER}/*" \
        \) \
        -print0 | xargs -0 yamllint
}

lint_docker_files() {
    find . -name Dockerfile -print0 | xargs -0 hadolint
}

lint_html_files(){
    tag="htmlhint-linter"
    docker build --quiet \
        -t "${tag}" \
        -f "${WORKSPACE_FOLDER}/.devcontainer/git-hooks/htmlhint/Dockerfile" \
        "${WORKSPACE_FOLDER}" | grep --quiet "^sha256:"

    find . -type f -name '*.html' -print0 \
    | xargs -0 -n 1 docker run --rm "${tag}" 2>&1 \
    | grep -v "The \`punycode\` module is deprecated" \
    | grep -v "Use \`node --trace-deprecation ...\` to show where the warning was created" \
    | grep -v "Scanned [^0] files, no errors found"
}

lint_js_files(){
    tag="eslint-linter"
    docker build --quiet \
        -t "${tag}" \
        -f "${WORKSPACE_FOLDER}/.devcontainer/git-hooks/eslint/Dockerfile" \
        "${WORKSPACE_FOLDER}" | grep --quiet "^sha256:"

    temp_lintjs_log="$(mktemp)"

    find . -type f -name '*.js' -print0 \
        | xargs -0 -n 1 docker run --rm "${tag}" \
        > "${temp_lintjs_log}" 2>&1
    if grep -Ev '^npm notice ' "${temp_lintjs_log}"; then
        echo "New erros found from lintjs." >&2
        exit 1
    fi
}

check_whitespace_error
check_linefeed_eof
check_usage_of_modified_files
lint_python_files
lint_sh_files
lint_helm_templates
lint_other_yaml_files
lint_docker_files
lint_html_files
lint_js_files

${LAUNCH_PROJECT} "$(basename "${PROJECT_FOLDER}")"
${LAUNCH_PROJECT} "$(basename "${PROJECT_OTHER_FOLDER}")"
