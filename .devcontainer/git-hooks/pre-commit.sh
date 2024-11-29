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
    ruff check --quiet --respect-gitignore
    grep --null -Rl '^#!/usr/bin/env python3' | xargs -0 ruff check --quiet
    ruff format --quiet --diff --respect-gitignore
    grep --null -Rl '^#!/usr/bin/env python3' | xargs -0 ruff format --quiet --diff
}

lint_sh_files() {
    find . -type f -name "*.sh" -print0 | xargs -0 shellcheck
}

lint_with_kubelint(){
    if ! kubelint_output="$(kube-linter lint --with-color "$1" 2>&1)"; then
        if ! echo "$kubelint_output" | grep "postgres apps/v1, Kind=StatefulSet" > /dev/null; then
            echo "$kubelint_output"
            return 1
        fi
    fi
}

lint_helm_templates() {
    local directories=("${PROJECT_FOLDER}" "${PROJECT_OTHER_FOLDER}")
    for dir in "${directories[@]}"; do
        while IFS= read -r -d '' item; do
            local resolved_template
            resolved_template=$("${RESOLVE_HELM_TEMPLATE_TOOL}" "$item")
            yamllint --strict "$resolved_template"
            lint_with_kubelint "$resolved_template"
            kubectl create namespace "$(basename "$dir")" > /dev/null 2>&1 || true
            kubectl config set-context --current --namespace="$(basename "$dir")" > /dev/null
            kubectl apply --dry-run=server -f "$resolved_template" > /dev/null
        done < <(find "${dir}" -mindepth 2 -maxdepth 2 -type d -print0)
    done
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

test_no_broken_links(){
    broken_links="$(find "$WORKSPACE_FOLDER" -xtype l)"
    if [ -n "$broken_links" ]; then
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
test_no_broken_links

if [[ -n "${SKIP_LAUNCH_TESTS:-}" || "$(kubectl config current-context)" != "k3d-k3s-default" ]]; then
    exit 0
fi

git clean -f -x -e "/.env"

echo "Testing ${PROJECT_FOLDER} launch..."
${LAUNCH_PROJECT} "$(basename "${PROJECT_FOLDER}")" > /dev/null
echo "Testing ${PROJECT_OTHER_FOLDER} launch..."
${LAUNCH_PROJECT} "$(basename "${PROJECT_OTHER_FOLDER}")" > /dev/null
