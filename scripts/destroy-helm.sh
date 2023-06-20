#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="./tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

if ! command -v helm 1> /dev/null 2> /dev/null; then
  echo "helm cli not found" >&2
  exit 1
fi

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

if ! command -v jq 1> /dev/null 2> /dev/null; then
  echo "jq cli not found" >&2
  exit 1
fi

INSTALLED_MODULE_ID=$(kubectl get cm "${NAME}-module" -n "${NAMESPACE}" -o json | jq -r '.data.moduleId // empty')

if [[ "${INSTALLED_MODULE_ID}" != "${MODULE_ID}" ]]; then
  echo "Gitea installed by a different module. Skipping"
  exit 0
fi

helm delete -n "${NAMESPACE}" "${NAME}"
