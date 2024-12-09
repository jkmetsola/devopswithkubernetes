#!/bin/bash

set -euo pipefail

git clean -f -x -e "/.env"

kubectl config use-context k3d-k3s-default

tools/launch_project.sh project
tools/launch_project.sh project-other
