#!/bin/bash

set -euo pipefail

GKE_SA_KEY_JSON=~/GKE_SA_KEY.json

echo "$GKE_SA_KEY" > "$GKE_SA_KEY_JSON"
gcloud auth login --cred-file="$GKE_SA_KEY_JSON"

