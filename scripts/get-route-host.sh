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

HOST=$(kubectl get route -n "${NAMESPACE}" "${NAME}" --output JSON | jq -r '.spec.host')

if [[ -z "${HOST}" ]]; then
  echo "Unable to find host from route ${NAMESPACE}/${NAME}" >&2
  kubectl get route -n "${NAMESPACE}" >&2
  exit 1
fi

count=0
until curl -X GET -Iqs --insecure "https://${HOST}" | grep -q -E "403|200" || \
  [[ $count -eq 30 ]]
do
    sleep 15
    count=$((count + 1))
done

if [[ "${count}" -eq 30 ]]; then
  echo "Timed out waiting for host to be ready: ${HOST}" >&2
  exit 1
fi

PASSWORD=$(kubectl get gitea -n "${NAMESPACE}" "${NAME}" -o yaml | jq -r '.status.adminPassword')

jq -n --arg HOST "${HOST}" --arg PASSWORD "${PASSWORD}" '{"host": $HOST, "password": $PASSWORD}'
