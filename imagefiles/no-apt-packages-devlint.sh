#!/bin/bash
set -euo pipefail

install_hadolint() {
    wget --progress=dot:giga -O /bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64
    chmod +x /bin/hadolint
}

install_actionlint() {
    wget --progress=dot:giga https://github.com/rhysd/actionlint/releases/download/v1.6.27/actionlint_1.6.27_linux_amd64.tar.gz
    mkdir actionlint_folder
    tar -xf actionlint_1.6.27_linux_amd64.tar.gz -C actionlint_folder
    mv actionlint_folder/actionlint /usr/local/bin/
    rm -rf actionlint_folder
    chmod +x /usr/local/bin/actionlint
}

install_hadolint
install_actionlint
