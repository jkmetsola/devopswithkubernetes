#!/bin/bash

set -euo pipefail

install_sops() {
    # Install
    curl -LO https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.linux.amd64
    cp sops-v3.9.1.linux.amd64 /usr/local/bin/sops
    chmod +x /usr/local/bin/sops

    # Download the checksums file, certificate and signature
    curl -LO https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.checksums.txt
    curl -LO https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.checksums.pem
    curl -LO https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.checksums.sig

    # Verify the checksums file
    cosign verify-blob sops-v3.9.1.checksums.txt \
    --certificate sops-v3.9.1.checksums.pem \
    --signature sops-v3.9.1.checksums.sig \
    --certificate-identity-regexp=https://github.com/getsops \
    --certificate-oidc-issuer=https://token.actions.githubusercontent.com

    # Verify the binary using the checksums file
    sha256sum -c sops-v3.9.1.checksums.txt --ignore-missing

    # Download the metadata file
    curl -LO  https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.intoto.jsonl

    # Verify the provenance of the artifact
    slsa-verifier verify-artifact sops-v3.9.1.linux.amd64 \
    --provenance-path sops-v3.9.1.intoto.jsonl \
    --source-uri github.com/getsops/sops \
    --source-tag v3.9.1
}

install_slsa_verifier() {
    wget https://github.com/slsa-framework/slsa-verifier/releases/download/v2.6.0/slsa-verifier-linux-amd64 \
        -O /usr/bin/slsa-verifier
    chmod +x /usr/bin/slsa-verifier
}

install_slsa_verifier
install_sops
