#!/usr/bin/env bash
# Waits until the newest deployed revision of a proxy is READY in an environment.
# Usage: wait-for-deployment.sh <org> <env> <proxy> [timeout_seconds]
# On success writes the revision number to <env>_revision.txt and exits 0.
# Exits 1 on ERROR state or timeout. Needs: gcloud, curl, python3.
set -euo pipefail

ORG="$1"; ENV="$2"; PROXY="$3"; TIMEOUT="${4:-300}"
BASE="https://apigee.googleapis.com/v1/organizations/${ORG}/environments/${ENV}/apis/${PROXY}"

while true; do
  TOKEN="$(gcloud auth print-access-token)"

  REV="$(curl -sS --fail-with-body -H "Authorization: Bearer ${TOKEN}" "${BASE}/deployments" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin).get("deployments",[]); print(max((int(x["revision"]) for x in d), default=""))')"

  if [[ -n "${REV}" ]]; then
    STATE="$(curl -sS --fail-with-body -H "Authorization: Bearer ${TOKEN}" "${BASE}/revisions/${REV}/deployments" \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("state","UNKNOWN"))')"
  else
    STATE="NOT_DEPLOYED"
  fi

  echo "$(date -u +%H:%M:%S) ${ENV}: revision=${REV:-none} state=${STATE}"

  if [[ "${STATE}" == "READY" ]]; then
    echo "${REV}" > "${ENV}_revision.txt"
    exit 0
  fi
  if [[ "${STATE}" == "ERROR" ]]; then
    echo "Deployment of ${PROXY} revision ${REV} to ${ENV} failed" >&2
    exit 1
  fi
  if (( SECONDS >= TIMEOUT )); then
    echo "Timed out after ${TIMEOUT}s waiting for ${PROXY} in ${ENV}" >&2
    exit 1
  fi
  sleep 10
done
