#!/bin/bash

set -euo pipefail

PYTHONPATH=/app application_launcher/application_launcher.py --port "${PORT}" --logfile "$(mktemp)"
