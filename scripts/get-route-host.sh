#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')
NAMESPACE=$(echo "${INPUT}" | grep "namespace" | sed -E 's/.*"namespace": ?"([^"]*)".*/\1/g')
NAME=$(echo "${INPUT}" | grep "name" | sed -E 's/.*"name": ?"([^"]*)".*/\1/g')

export PATH="${BIN_DIR}:${PATH}"

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

if ! command -v jq 1> /dev/null 2> /dev/null; then
  echo "jq cli not found" >&2
  exit 1
fi

count=0
until kubectl get gitea -n "${NAMESPACE}" "${NAME}" 1> /dev/null 2> /dev/null && \
  [[ $(kubectl get gitea -n "${NAMESPACE}" "${NAME}" -o json | jq -r '.status.adminSetupComplete // false') == "true" ]]
do
  if [[ ${count} -eq 30 ]]; then
    break
  fi

  count=$((count + 1))
  sleep 30
done

if ! kubectl get gitea -n "${NAMESPACE}" "${NAME}" 1> /dev/null 2> /dev/null; then
  echo "Gitea cr not found" >&2
  kubectl get gitea -n "${NAMESPACE}" >&2
  exit 1
fi

if [[ $(kubectl get gitea -n "${NAMESPACE}" "${NAME}" -o json | jq -r '.status.adminSetupComplete // false') != "true" ]]; then
  echo "Timed out waiting for gitea admin setup to complete" >&2
  kubectl get gitea -n "${NAMESPACE}" "${NAME}" -o yaml >&2
  exit 1
fi

PASSWORD=$(kubectl get gitea -n "${NAMESPACE}" "${NAME}" -o json | jq -r '.status.adminPassword // empty')
HOST=$(kubectl get gitea -n "${NAMESPACE}" "${NAME}" -o json | jq -r '.status.giteaHostname // empty')

count=0
until [[ "$(curl -sk -X GET "https://${HOST}/api/v1/settings/api" | jq 'keys | length')" -gt 0 ]]; do
    if [[ $count -eq 30 ]]; then
      break
    fi

    sleep 15
    count=$((count + 1))
done

if [[ "${count}" -eq 30 ]]; then
  echo "Timed out waiting for host to be ready: ${HOST}" >&2
  exit 1
fi

jq -n --arg HOST "${HOST}" --arg PASSWORD "${PASSWORD}" '{"host": $HOST, "password": $PASSWORD}'
