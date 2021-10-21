#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
OPENSHIFT="$3"

# Don't run if on kubernetes
if [ ${OPENSHIFT} != true ]; then
  echo "Skip, not installing into Openshift"
  exit 0 
fi

PODS="name=postgresql-${NAME},app=${NAME}"
ROUTES="${NAME}"
IFS=","

for POD in ${PODS}; do

  count=0
  until [ $(kubectl get pods -l "${POD}" -n "${NAMESPACE}" 2> /dev/null | wc -l) -gt 0 ];
  do
    if [[ ${count} -eq 24 ]]; then
      echo "Timed out waiting for pod -l ${POD} in ${NAMESPACE} to be created"
      kubectl get pods -l "${POD}" -n "${NAMESPACE}" 
      exit 1
    else
      count=$((count + 1))
    fi

    echo "Waiting for pod -l ${POD} in ${NAMESPACE} to be created"
    sleep 10
  done

  until kubectl get pods -l "${POD}" -n "${NAMESPACE}" -o jsonpath="{.items[0]['status.phase']}" | grep -q Running;
  do
    if [[ ${count} -eq 24 ]]; then
      echo "Timed out waiting for pod -l ${POD} in ${NAMESPACE} to be running"
      kubectl get pods -l "${POD}"  -n "${NAMESPACE}" 
      exit 1
    else
      count=$((count + 1))
    fi

    echo "Waiting for pod -l ${POD} in ${NAMESPACE} to be running"
    sleep 10
  done

done


for ROUTE in ${ROUTES}; do
  count=0
  until kubectl get route "${ROUTE}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null ;
  do
    if [[ ${count} -eq 30 ]]; then
      echo "Timed out waiting for route/${ROUTE} in ${NAMESPACE} to be created"
      kubectl get route "${ROUTE}" -n "${NAMESPACE}" 
      exit 1
    else
      count=$((count + 1))
    fi

    echo "Waiting for route/${ROUTE} in ${NAMESPACE} to be created"
    sleep 10
  done
done