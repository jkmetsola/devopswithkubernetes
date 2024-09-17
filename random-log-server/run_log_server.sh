#!/bin/bash

set -euo pipefail

log_server/log_server.py --port "${PORT}" --logfile "${LOG_FILE}"
