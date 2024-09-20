#!/bin/bash

set -euo pipefail

random_string_printer/random_string_printer.py --logfile "${LOG_FILE}" --pongfile "${PONG_FILE}"
