#!/bin/bash
set -euo pipefail

install_k3d() {
    wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.7.3 bash
}

install_yq() {
    wget https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 -O /usr/bin/yq
    chmod +x /usr/bin/yq
}

install_k3d
install_yq
