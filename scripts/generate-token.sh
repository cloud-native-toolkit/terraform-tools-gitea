#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
TOKEN_NAME="$3"
HOST="$4"

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

if [[ -z "${USERNAME}" ]]; then
  echo "USERNAME required as environment variable" >&2
  exit 1
fi
if [[ -z "${PASSWORD}" ]]; then
  echo "PASSWORD required as environment variable" >&2
  exit 1
fi

RESULT=$(curl -XPOST -H "Content-Type: application/json" -k -s -d "{\"name\":\"${TOKEN_NAME}\",\"scopes\":[\"all\"]}" -u "${USERNAME}:${PASSWORD}" "https://${HOST}/api/v1/users/${USERNAME}/tokens")

TOKEN=$(echo "${RESULT}" | jq -r '.sha1 // empty')

if [[ -z "${TOKEN}" ]]; then
  echo "Unable to retrieve token: ${RESULT}" >&2
  exit 1
fi

kubectl create secret generic "${NAME}" \
  -n "${NAMESPACE}" \
  --from-literal=token="${TOKEN}" \
  --dry-run=client \
  -o yaml | \
  kubectl apply -f -
