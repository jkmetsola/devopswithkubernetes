#!/bin/bash

set -euo pipefail

k3d cluster delete
k3d cluster create --host-alias 0.0.0.0:host.docker.internal -a 2 --k3s-arg "--tls-san=host.docker.internal@server:0"
KUBE_API_ADDRESS="$(kubectl config view -o jsonpath='{.clusters[?(@.name=="k3d-k3s-default")].cluster.server}')"
PORT=$(echo "$KUBE_API_ADDRESS" | awk -F: '{print $NF}')
kubectl config set clusters.k3d-k3s-default.server https://host.docker.internal:"$PORT"
kubectl cluster-info

docker build -f "excercise101/Dockerfile" -t excercise101:latest "excercise101"
k3d image import excercise101:latest
kubectl apply -f excercise101/deployment.yaml

docker build -f "excercise102/Dockerfile" -t excercise102:latest "excercise102"
k3d image import excercise102:latest
