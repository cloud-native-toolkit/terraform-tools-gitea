#!/usr/bin/env bash

INPUT=$(tee)

BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')
export PATH="${BIN_DIR}:${PATH}"

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

if ! command -v jq 1> /dev/null 2> /dev/null; then
  echo "jq cli not found" >&2
  exit 1
fi

export KUBECONFIG=$(echo "${INPUT}" | jq -r '.kube_config')
NAMESPACE=$(echo "${INPUT}" | jq -r '.namespace')
NAME=$(echo "${INPUT}" | jq -r '.name')
CLUSTER_TYPE=$(echo "${INPUT}" | jq -r '.cluster_type')

SECRET_NAME="${NAME}-admin"

RESOURCE="route"
if [[ "${CLUSTER_TYPE}" == "kubernetes" ]]; then
  RESOURCE="ingress"
fi

count=0
until [[ $(kubectl get "${RESOURCE}" -n "${NAMESPACE}" -l "app.kubernetes.io/instance=${NAME}" -o json | jq '.items | length') -gt 0 ]]
do
  if [[ ${count} -eq 30 ]]; then
    break
  fi

  count=$((count + 1))
  sleep 30
done

if [[ ${count} -eq 30 ]]; then
  echo "Timed out waiting for ${RESOURCE} with label app.kubernetes.io/instance=${NAME} in ${NAMESPACE} namespace" >&2
  kubectl get "${RESOURCE}" -n "${NAMESPACE}" -o yaml >&2
  exit 1
fi

USERNAME=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o json | jq -r '.data.username | @base64d')
PASSWORD=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o json | jq -r '.data.password | @base64d')

RESOURCE_NAME=$(kubectl get "${RESOURCE}" -n "${NAMESPACE}" -l "app.kubernetes.io/instance=${NAME}" -o json | jq -r '.items[0] | (.kind + "/" + .metadata.name)')

HOST=$(kubectl get "${RESOURCE_NAME}" -n "${NAMESPACE}" -o json | jq -r '.spec.host // .spec.rules[0].host // empty')

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

jq -n --arg HOST "${HOST}" --arg USERNAME "${USERNAME}" --arg PASSWORD "${PASSWORD}" '{"host": $HOST, "username": $USERNAME, "password": $PASSWORD}'
