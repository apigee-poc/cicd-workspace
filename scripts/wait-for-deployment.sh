#!/usr/bin/env bash
# Waits until a proxy deployment is READY in an environment.
# Usage: wait-for-deployment.sh <org> <env> <proxy> [timeout_seconds] [expected_revision]
# If expected_revision is omitted, waits for the highest revision in deployments.
# On success writes the revision number to <env>_revision.txt and exits 0.
# Exits 1 on ERROR state or timeout. Needs: gcloud, curl (Python comes from gcloud if python3 is missing).
set -euo pipefail

# JSON parsing: system python3 if the image has it, otherwise the Python bundled with gcloud
PY="$(command -v python3 || gcloud info --format='value(basic.python_location)')"

ORG="$1"; ENV="$2"; PROXY="$3"; TIMEOUT="${4:-300}"; TARGET_REV="${5:-}"
BASE="https://apigee.googleapis.com/v1/organizations/${ORG}/environments/${ENV}/apis/${PROXY}"

while true; do
  TOKEN="$(gcloud auth print-access-token 2>/dev/null || ([ -f /workspace/.token ] && cat /workspace/.token) || true)"

  if [[ -n "${TARGET_REV}" ]]; then
    REV="${TARGET_REV}"
  else
    REV="$(curl -sS --fail-with-body -H "Authorization: Bearer ${TOKEN}" "${BASE}/deployments" \
      | "${PY}" -c 'import json,sys; d=json.load(sys.stdin).get("deployments",[]); print(max((int(x["revision"]) for x in d), default=""))')"
  fi

  if [[ -n "${REV}" ]]; then
    STATE="$(curl -sS -H "Authorization: Bearer ${TOKEN}" "${BASE}/revisions/${REV}/deployments" 2>/dev/null \
      | "${PY}" -c 'import json,sys; print(json.load(sys.stdin).get("state","UNKNOWN"))' 2>/dev/null || echo "UNKNOWN")"
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
