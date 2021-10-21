#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
OPENSHIFT="$3"

# Don't run if on kubernetes
if [ ${OPENSHIFT} != true ]; then
  echo "Skip, not installing into Openshift"
  exit 0 
fi

DEPLOYMENTS="${NAME}-controller-manager"
IFS=","

for DEPLOYMENT in ${DEPLOYMENTS}; do
  count=0
  until kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null ;
  do
    if [[ ${count} -eq 24 ]]; then
      echo "Timed out waiting for deployment/${DEPLOYMENT} in ${NAMESPACE} to start"
      kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" 
      exit 1
    else
      count=$((count + 1))
    fi

    echo "Waiting for deployment/${DEPLOYMENT} in ${NAMESPACE} to start"
    sleep 10
  done

  if kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; then
    kubectl rollout status deployment "${DEPLOYMENT}" -n "${NAMESPACE}"
  fi
done

count=0
while kubectl get pods -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' -n "${NAMESPACE}" | grep -q Pending; do
  if [[ ${count} -eq 24 ]]; then
    echo "Timed out waiting for pods in ${NAMESPACE} to start"
    kubectl get pods -n "${NAMESPACE}"
    exit 1
  else
    count=$((count + 1))
  fi

  echo "Waiting for all pods in ${NAMESPACE} to start"
  sleep 10
done
