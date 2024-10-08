#!/bin/bash
set -euo pipefail

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"

# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"

CHECKED_FILES=$(git ls-files | grep -v 'manifests/global-values.yaml' | grep -v requirements-dev.txt)
ERROR_LOG_FILE=$(mktemp)


get_previous_commit_ref() {
    if ps -ocommand= -p $PPID | grep --quiet -e '--amend'; then
        echo "HEAD~1"
    else
        echo "HEAD"
    fi
}

check_whitespace_error() {
    git diff-index --check --cached HEAD --
}

check_linefeed_eof() {
    git diff-index --cached --name-only --diff-filter d HEAD -- \
    | xargs -L 1 --no-run-if-empty "${CHECK_LINEFEED}"
}

check_matches_for_git_files() {
    check_if_file_is_whitelisted() {
        ./.devcontainer/whitelist_parser/whitelist_parser.py \
        --whitelist-file .devcontainer/git-hooks/whitelist.json \
        --previous-commit-sha "$(git rev-parse "$(get_previous_commit_ref)")" \
        --file "$1"
    }

    check_matches() {
        echo "$CHECKED_FILES" | xargs --no-run-if-empty grep -Fcw "$1" | awk -F: '{sum += $2} END {print sum}'
    }

    log_matches_as_error_conditionally() {
        if [[ $matches_found -ne "$desired_amount_of_matches" ]]; then
            {
                echo "ERROR with file '$1': "
                echo "Matches found:   $matches_found"
                echo "Matches desired: $desired_amount_of_matches"
                echo "$CHECKED_FILES" | xargs --no-run-if-empty grep --color=always -FHnw "$1"
                git status | grep --color=always -w "$1"
            } >> "$ERROR_LOG_FILE"
        fi
    }

    local desired_amount_of_matches="$2"
    local changed_files
    changed_files=$(git diff-index --cached --name-status --diff-filter "$1" -M HEAD -- | awk '{print $2}' | xargs --no-run-if-empty -L 1 basename)
    for file in $changed_files; do
        local matches_found=0
        if ! check_if_file_is_whitelisted "$file"; then
            matches_found=$((matches_found + $(check_matches "$file") ))
            log_matches_as_error_conditionally "$file"
        fi
    done
    if [[ -s "$ERROR_LOG_FILE" ]]; then
        cat "$ERROR_LOG_FILE"
        return 1
    fi
}

check_matches_for_renamed_files() {
    if ! check_matches_for_git_files R 0; then
        echo "There is match for original filename that was renamed, please check."
        exit 1
    fi
}

check_matches_for_added_files() {
    if ! check_matches_for_git_files A 1; then
        echo "There should be one and only one match for added filename, please check. (Use variables)"
        echo "If it is needed to use the filename without variable in multiple files, please add the filename to the exception list."
        exit 1
    fi
}

check_matches_for_modified_files() {
    if ! check_matches_for_git_files M 1; then
        echo "There should be one and only one match for modified filename, please check. (Use variables)"
        echo "If it is needed to use the filename without variable in multiple files, please add the filename to the exception list."
        exit 1
    fi
}

lint_python_files() {
    grep --null -Rl '^#!/usr/bin/env python3' | xargs -0 ruff check
    grep --null -Rl '^#!/usr/bin/env python3' | xargs -0 ruff format --diff
}

lint_sh_files() {
    find . -type f -name "*.sh" -print0 | xargs -0 shellcheck
}

lint_helm_templates() {
    find "${WORKSPACE_FOLDER}"/project -mindepth 2 -maxdepth 2 -type d -print0 \
        | xargs -0 -n 1 "${RESOLVE_HELM_TEMPLATE_TOOL}" \
        | xargs yamllint
}

lint_other_yaml_files() {
    find . -type f -name '*.yaml' ! -path './project/*' -print0 | xargs -0 yamllint
}

lint_docker_files() {
    find . -name Dockerfile -print0 | xargs -0 hadolint
}

lint_html_files(){
    docker build \
        -t htmlhint-linter \
        -f "${WORKSPACE_FOLDER}/.devcontainer/git-hooks/htmlhint/Dockerfile" \
        "${WORKSPACE_FOLDER}"
    find . -type f -name '*.html' -print0 | xargs -0 -t -I {} -n 1 \
        docker run --rm htmlhint-linter /workspace/{}
}

check_whitespace_error
check_linefeed_eof
check_matches_for_renamed_files
check_matches_for_added_files
check_matches_for_modified_files
lint_python_files
lint_sh_files
lint_helm_templates
lint_other_yaml_files
lint_docker_files
lint_html_files
