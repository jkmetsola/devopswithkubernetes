#!/bin/bash

set -euo pipefail

SKIP_LAUNCH_TESTS=1 .devcontainer/git-hooks/pre-commit.sh
