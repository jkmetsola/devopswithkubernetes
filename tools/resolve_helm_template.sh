#!/bin/bash

set -euo pipefail

MANIFEESTS_ROOTDIR="$1/manifests"

check_for_new_helm_errors() {
    if grep -v "found symbolic link in path:" "${temp_error_log}"; then
        echo "New errors seen in helm template output. Please check."
        exit 1
    fi
}

temp_production_yaml="$(mktemp --suffix .yaml)"
temp_resolved_production_yaml="$(mktemp --suffix .yaml)"
temp_error_log="$(mktemp --suffix .log)"
trap 'rm -f "${temp_error_log}"' EXIT
helm template --generate-name -f "${MANIFEESTS_ROOTDIR}/global-values.yaml" "${MANIFEESTS_ROOTDIR}" > "${temp_production_yaml}" 2> "${temp_error_log}"
check_for_new_helm_errors
yq eval -e 'explode(.)' "${temp_production_yaml}" > "${temp_resolved_production_yaml}"
echo "${temp_resolved_production_yaml}"
