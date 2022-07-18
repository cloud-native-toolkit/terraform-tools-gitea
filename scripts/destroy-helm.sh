#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"
KIND="$4"

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

if [[ $(kubectl get "${KIND}" -n "${NAMESPACE}" -l "app.kubernetes.io/instance=${NAME}" -o JSON | jq '.items | length') -eq 0 ]]; then
  echo "${KIND} instance not found wil instance name ${NAME}. Skipping delete"
  exit 0
fi

VALUES_FILE="${TMP_DIR}/${NAME}-values.yaml"

echo "${VALUES_FILE_CONTENT}" > "${VALUES_FILE}"

kubectl config set-context --current --namespace "${NAMESPACE}"

if [[ -n "${REPO}" ]]; then
  repo_config="--repo ${REPO}"
fi

# ${HELM} template "${NAME}" "${CHART}" ${repo_config} --values "${VALUES_FILE}" | kubectl delete -f -
helm template "${NAME}" "${CHART}" ${repo_config} --values "${VALUES_FILE}"
