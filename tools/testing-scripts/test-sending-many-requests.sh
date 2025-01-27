#!/bin/bash

set -euo pipefail

APP_NAME=$1
NAMESPACE=$2

REQUESTS_LOG="$(mktemp)"
URL="http://host.docker.internal:8081/$APP_NAME"
HPA_NAME="$APP_NAME-hpa"

MIN_REPLICAS="$(\
    kubectl --namespace "$NAMESPACE" get hpa frontend-hpa -o jsonpath="{.spec.minReplicas}"\
)"

check_scale_up(){
  if [ "$current_replicas" -gt "$MIN_REPLICAS" ]; then
      echo -e "\e[32mScale up success!\e[0m"
      return 0
  fi
  return 1
}

check_scale_down(){
  if [ "$current_replicas" -eq "$MIN_REPLICAS" ]; then
      echo -e "\e[32mScale down success!\e[0m"
      return 0
  fi
  return 1
}

get_hpa_status(){
  kubectl --namespace "$NAMESPACE" get hpa "$HPA_NAME"
}

get_hpa_current_replicas(){
  kubectl --namespace "$NAMESPACE" get hpa "$HPA_NAME" -o jsonpath='{.status.currentReplicas}'
}

wait_for_scaling(){
  for i in {1..30}; do
    get_hpa_status
    current_replicas="$(get_hpa_current_replicas)"
    if [[ "$1" == "up" ]] && check_scale_up; then
      return 0
    elif [[ "$1" == "down" ]] && check_scale_down; then
      return 0
    fi
    sleep 5
  done
  return 1
}

main(){
  echo "Outputting requests log to $REQUESTS_LOG"
  get_hpa_status
  for i in {1..1000}; do
    echo "Request #$i: $(curl -o /dev/null -s -w "%{http_code}\n" "$URL")" >> "$REQUESTS_LOG"
    sleep 0.0005
  done
  wait_for_scaling up
  wait_for_scaling down
}
main
