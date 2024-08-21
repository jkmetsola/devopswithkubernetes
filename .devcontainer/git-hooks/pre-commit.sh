#!/bin/bash
set -euo pipefail

CHECKED_FILES=$(git ls-files)
ERROR_LOG_FILE=$(mktemp)

if ps -ocommand= -p $PPID | grep --quiet -e '--amend'; then
    PREVIOUS_COMMIT_REF=HEAD~1
else
    PREVIOUS_COMMIT_REF=HEAD
fi

check_whitespace_error() {
    git diff-index --check --cached HEAD --
}

check_linefeed_eof() {
    git diff-index --cached --name-only --diff-filter d HEAD -- \
    | xargs -L 1 --no-run-if-empty "${CHECK_LINEFEED}"
}

check_matches_for_git_files(){
    check_if_file_is_whitelisted() {
        ./.devcontainer/whitelist_parser/whitelist_parser.py \
        --whitelist-file .devcontainer/git-hooks/whitelist.json \
        --previous-commit-sha "$(git rev-parse ${PREVIOUS_COMMIT_REF})" \
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

WORKSPACE_FOLDER="$(git rev-parse --show-toplevel)"
# shellcheck source=.env
source "$WORKSPACE_FOLDER/.env"
# shellcheck source=.devcontainer/setupEnv.sh
source "${SETUP_ENV_PATH}" "false"
check_whitespace_error
check_linefeed_eof
check_matches_for_renamed_files
check_matches_for_added_files
check_matches_for_modified_files
ruff check --exclude .vscode-server
ruff format --exclude .vscode-server --diff
find . -type f -name "*.sh" -print0 | xargs -0 shellcheck
hadolint Dockerfile
actionlint -ignore 'workflow is empty'
