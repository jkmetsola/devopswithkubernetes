#!/bin/bash

set -euo pipefail

REQUESTS_LOG="$(mktemp)"
URL="http://host.docker.internal:8081/frontend"

check_scale_up(){
  if [ "$current_replicas" -gt 1 ]; then
      echo -e "\e[32mScale up success!\e[0m"
      return 0
  fi
  return 1
}

check_scale_down(){
  if [ "$current_replicas" -eq 1 ]; then
      echo -e "\e[32mScale down success!\e[0m"
      return 0
  fi
  return 1
}

wait_for_scaling(){
  for i in {1..30}; do
    kubectl get hpa frontend-hpa
    current_replicas="$(kubectl get hpa frontend-hpa -o jsonpath='{.status.currentReplicas}')"
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
  kubectl get hpa
  for i in {1..1000}; do
    echo "Request #$i: $(curl -o /dev/null -s -w "%{http_code}\n" $URL)" >> "$REQUESTS_LOG"
    sleep 0.0005
  done
  wait_for_scaling up
  wait_for_scaling down
}
main
