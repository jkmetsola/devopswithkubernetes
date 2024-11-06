#!/bin/bash

set -euo pipefail

mkdir -p ~/.age
echo "${SOPS_AGE_KEY}" > ~/.age/key
