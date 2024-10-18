#!/bin/bash

set -euo pipefail

create_cluster() {
    k3d cluster delete
    k3d cluster create \
        --host-alias 0.0.0.0:host.docker.internal \
        --agents 2 \
        --k3s-arg "--tls-san=host.docker.internal@server:0" \
        --k3s-arg="--disable=traefik@server:0" \
        --port 8081:80@loadbalancer \
        --api-port host.docker.internal:6550
    docker exec k3d-k3s-default-agent-0 mkdir -p /tmp/kube
    helm install --debug ingress-nginx ingress-nginx \
        --repo https://kubernetes.github.io/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --version 4.11.3 \
        --wait
}

create_cluster
