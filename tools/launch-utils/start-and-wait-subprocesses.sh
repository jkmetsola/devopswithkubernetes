#!/bin/bash

set -euo pipefail

COMMANDS=("$@")

EXECUTION_PIDS=()

error_exit_hook(){
    if [ "$?" -ne 0 ]; then
        echo "Script exited with error."
        for pid in "${EXECUTION_PIDS[@]}"; do
            echo "Killing pid $pid" >&2
            kill "$pid" 2>/dev/null || true
        done
    fi
}

start_subprocesses() {
    for cmd in "${COMMANDS[@]}"; do
        temp_logs="$(mktemp)"
        eval "$cmd > $temp_logs ${STDERR_TO_FILE:+2>&1}" &
        execution_pid=$!
        echo "Process $cmd started with pid $execution_pid. Logs: $temp_logs"
        EXECUTION_PIDS+=("$execution_pid")
    done
}

wait_subprocesses() {
    for pid in "${EXECUTION_PIDS[@]}"; do
        if ! wait "$pid"; then
            echo -e "\e[31mProcess with PID $pid failed.\e[0m" >&2
            exit 1
        else
            echo -e "\e[32mProcess with PID $pid succeeded.\e[0m"
        fi
    done
}

main() {
    if [[ -n "${DEBUG:-}" ]]; then
        set -x
        export DEBUG
    fi
    trap error_exit_hook EXIT
    start_subprocesses
    wait_subprocesses
}

main
