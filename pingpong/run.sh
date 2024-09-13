#!/bin/bash

set -euo pipefail

PYTHONPATH=/app pingpong/pingpong.py --port "${PORT}" --counter-file "$(mktemp)"
