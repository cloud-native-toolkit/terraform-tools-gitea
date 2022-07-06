#!/usr/bin/env bash

INPUT=$(tee)

BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')

export PATH="${BIN_DIR}:${PATH}"

export KUBECONFIG=$(echo "${INPUT}" | jq -r '.kube_confit')
NAMESPACE=$(echo "${INPUT}" | jq -r '.namespace')
NAME=$(echo "${INPUT}" | jq -r '.name')

if ! kubectl get secret -n "${NAMESPACE}" "${NAME}" 1> /dev/null 2> /dev/null; then
  echo '{"token": ""}'
  exit 0
fi

TOKEN=$(kubectl get secret -n "${NAMESPACE}" "${NAME}" -o json | jq -r '.data.token | @base64d')

jq -n --arg TOKEN "${TOKEN}" '{"token": $TOKEN}'
