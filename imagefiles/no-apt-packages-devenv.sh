#!/bin/bash
set -euo pipefail

install_k3d() {
    wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.7.3 bash
}

install_k3d
