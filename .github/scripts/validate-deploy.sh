#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

BIN_DIR=$(cat .bin_dir)
export PATH="${BIN_DIR}:${PATH}"

if [[ -f .kubeconfig ]]; then
  KUBECONFIG=$(cat .kubeconfig)
else
  KUBECONFIG="${PWD}/.kube/config"
fi
export KUBECONFIG

CLUSTER_TYPE=$(cat .cluster_type)

echo "listing directory contents"
ls -A

NAMESPACE=$(cat .namespace)

echo "Verifying resources in ${NAMESPACE} namespace for module ${NAME}"

PODS=$(kubectl get -n "${NAMESPACE}" pods -o jsonpath='{range .items[*]}{.status.phase}{": "}{.kind}{"/"}{.metadata.name}{"\n"}{end}' | grep -v "Running" | grep -v "Succeeded")
POD_STATUSES=$(echo "${PODS}" | sed -E "s/(.*):.*/\1/g")
if [[ -n "${POD_STATUSES}" ]]; then
  echo "  Pods have non-success statuses: ${PODS}"
  exit 1
fi

set -e

if [[ "${CLUSTER_TYPE}" == "kubernetes" ]] || [[ "${CLUSTER_TYPE}" =~ iks.* ]]; then
  ENDPOINTS=$(kubectl get ingress -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{range .spec.rules[*]}{"https://"}{.host}{"\n"}{end}{end}')
else
  ENDPOINTS=$(kubectl get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{"https://"}{.spec.host}{.spec.path}{"\n"}{end}')
fi

echo "Validating endpoints:"
echo "${ENDPOINTS}"

echo "${ENDPOINTS}" | while read endpoint; do
  if [[ -n "${endpoint}" ]]; then
    ${SCRIPT_DIR}/waitForEndpoint.sh "${endpoint}" 10 10
  fi
done

echo "Endpoints validated"

if [[ "${CLUSTER_TYPE}" =~ ocp4 ]] && [[ -n "${CONSOLE_LINK_NAME}" ]]; then
  echo "Validating consolelink"
  if [[ $(kubectl get consolelink "${CONSOLE_LINK_NAME}" | wc -l) -eq 0 ]]; then
    echo "   ConsoleLink not found"
    exit 1
  fi
fi

GIT_HOST=$(cat .host)
GIT_USERNAME=$(cat .username)
PASSWORD=$(cat .password)
GIT_TOKEN=$(cat .token)

export GIT_HOST GIT_USERNAME GIT_TOKEN

echo "Getting repos with password"
curl -Ls -X GET -H "Content-Type: application/json" -u "${GIT_USERNAME}:${PASSWORD}" "https://${GIT_HOST}/api/v1/user/repos"

echo "Getting repos with token"
curl -Ls -X GET -H "Content-Type: application/json" -H "Authorization: token ${GIT_TOKEN}" "https://${GIT_HOST}/api/v1/user/repos"

## Create a repo
echo "Creating repo: test-repo"
REPO_URL=$(gitu create test-repo -g "https://${GIT_HOST}/${GIT_USERNAME}" --output json | jq -r '.url')

## Clone the repo
echo "Cloning repo: ${REPO_URL}"
count=0
until gitu clone "${REPO_URL}" ./test-repo --debug; do
  if [[ $count -eq 10 ]]; then
    echo "Timed out waiting for clone"
    exit 1
  fi

  count=$((count + 1))
  echo "  Error cloning repo: ${REPO_URL}. Sleeping for 30 sec"
  sleep 30
done

## Delete repo
echo "Deleting repo: ${REPO_URL}"
gitu delete "${REPO_URL}" || exit 1

exit 0
