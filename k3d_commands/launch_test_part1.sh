#!/bin/bash

set -euo pipefail

k3d cluster delete
k3d cluster create --host-alias 0.0.0.0:host.docker.internal -a 2 --k3s-arg "--tls-san=host.docker.internal@server:0"
KUBE_API_ADDRESS="$(kubectl config view -o jsonpath='{.clusters[?(@.name=="k3d-k3s-default")].cluster.server}')"
PORT=$(echo "$KUBE_API_ADDRESS" | awk -F: '{print $NF}')
kubectl config set clusters.k3d-k3s-default.server https://host.docker.internal:"$PORT"
kubectl cluster-info
kubectl create deployment hashgenerator-dep --image=jakousa/dwk-app1
