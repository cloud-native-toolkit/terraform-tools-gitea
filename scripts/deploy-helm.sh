#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"
KIND="$4"

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="./tmp"
fi
mkdir -p "${TMP_DIR}"

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

if helm status "${NAME}" 1> /dev/null 2> /dev/null; then
  echo "Gitea already installed. Skipping..."
  exit 0
fi

VALUES_FILE="${TMP_DIR}/${NAME}-values.yaml"

echo "${VALUES_FILE_CONTENT}" > "${VALUES_FILE}"

if [[ -n "${REPO}" ]]; then
  repo_config="--repo ${REPO}"
fi

helm upgrade -i -n "${NAMESPACE}" "${NAME}" "${CHART}" ${repo_config} --values "${VALUES_FILE}"
