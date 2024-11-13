#!/bin/bash

set -euo pipefail

gcloud container clusters create dwk-cluster --zone=europe-north1-b --cluster-version=1.29
