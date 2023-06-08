#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

NAMESPACE="$1"
NAME="$2"
OPENSHIFT="$3"

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

if ! command -v jq 1> /dev/null 2> /dev/null; then
  echo "jq not found" >&2
  exit 1
fi

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

if [[ "${OPENSHIFT}" == "true" ]]; then
  kubectl get route -n "${NAMESPACE}" -o json | jq -r '.items[].spec.host' | while read host; do
    "${SCRIPT_DIR}/waitForEndpoint.sh" "${host}"
  done
else
  kubectl get ingress -n "${NAMESPACE}" -o json | jq -r '.items[].spec.rules[].host' | while read host; do
    "${SCRIPT_DIR}/waitForEndpoint.sh" "${host}"
  done
fi
