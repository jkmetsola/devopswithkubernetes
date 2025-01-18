#!/bin/bash
set -euo pipefail

ARGO_DOWNLOAD_URL=$1

install_k3d() {
    wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.7.3 bash
}

install_yq() {
    wget https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 -O /usr/bin/yq
    chmod +x /usr/bin/yq
}

install_argo_kubectl_plugin(){
    curl -LO "$ARGO_DOWNLOAD_URL/kubectl-argo-rollouts-linux-amd64"
    chmod +x ./kubectl-argo-rollouts-linux-amd64
    mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
}

install_k3d
install_yq
install_argo_kubectl_plugin
