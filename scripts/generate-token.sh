#!/usr/bin/env bash

NAMESPACE="$1"
HOST="$2"

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

RESULT=$(curl -XPOST -H "Content-Type: application/json" -k -d '{"name":"default"}' -u "${USERNAME}:${PASSWORD}" "https://${HOST}/api/v1/users/${USERNAME}/tokens")

TOKEN=$(echo "${RESULT}" | jq -r '.sha1 // empty')

if [[ -z "${TOKEN}" ]]; then
  echo "Unable to retrieve token: ${RESULT}" >&2
  exit 1
fi

kubectl create secret generic gitea-token -n "${NAMESPACE}" --from-literal=token="${TOKEN}"
