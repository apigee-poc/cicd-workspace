#!/usr/bin/env bash
# Creates a versioned KVM in an Apigee environment.
# The KVM name is "<base_name>-<version_suffix>", for example
# "hello-v1-config-a1b2c3d" where a1b2c3d is the short commit SHA.
#
# Usage: create-versioned-kvm.sh <org> <env> <version_suffix>
#
# Reads KVM definitions from: src/main/apigee/environments/<env>/kvms/*.json
# For each definition file:
#   1. Creates the KVM named "<base_name>-<version_suffix>" (encrypted by default)
#   2. Creates all entries with values from the definition file
#
# Idempotent: safe to run multiple times (409 on existing KVM/entry is handled).
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $(basename "$0") <org> <env> <version_suffix>" >&2
  exit 1
fi

ORG="$1"; ENV="$2"; VERSION="$3"
KVM_DIR="src/main/apigee/environments/${ENV}/kvms"
TOKEN="$(gcloud auth print-access-token 2>/dev/null \
         || ([ -f /workspace/.token ] && cat /workspace/.token) || true)"
TOKEN="$(echo "${TOKEN}" | tr -d '\r\n[:space:]')"

if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: Unable to acquire auth token (gcloud or /workspace/.token)" >&2
  exit 1
fi

API="https://apigee.googleapis.com/v1/organizations/${ORG}/environments/${ENV}/keyvaluemaps"
PY="$(command -v python3 || gcloud info --format='value(basic.python_location)')"

if [ ! -d "${KVM_DIR}" ]; then
  echo "No KVM definitions at ${KVM_DIR} — skipping."
  exit 0
fi

RESP_FILE=$(mktemp 2>/dev/null || echo "/tmp/kvm_resp_$$.json")

for DEF_FILE in "${KVM_DIR}"/*.json; do
  [ -f "${DEF_FILE}" ] || continue

  BASE_NAME="$("${PY}" -c "import json,sys; print(json.load(sys.stdin)['name'])" < "${DEF_FILE}")"
  VERSIONED_NAME="${BASE_NAME}-${VERSION}"
  ENCRYPTED="$("${PY}" -c "import json,sys; print(str(json.load(sys.stdin).get('encrypted',True)).lower())" < "${DEF_FILE}")"

  echo "Creating KVM: ${VERSIONED_NAME} (encrypted=${ENCRYPTED})"

  # Create the KVM (200/201 = success, 409 = already exists)
  HTTP_CODE=$(curl -sS -w "%{http_code}" -o "${RESP_FILE}" \
    -X POST -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${VERSIONED_NAME}\",\"encrypted\":${ENCRYPTED}}" \
    "${API}")

  if [[ "${HTTP_CODE}" =~ ^20[01]$ ]]; then
    echo "  KVM created."
  elif [[ "${HTTP_CODE}" == "409" ]]; then
    echo "  KVM already exists (idempotent)."
  else
    echo "  ERROR: Failed to create KVM (HTTP ${HTTP_CODE}):" >&2
    cat "${RESP_FILE}" >&2 || true
    echo "" >&2
    rm -f "${RESP_FILE}"
    exit 1
  fi

  # Create entries from the definition file
  "${PY}" -c "
import json, sys
data = json.load(sys.stdin)
for entry in data.get('entries', []):
    print(json.dumps({'name': entry['name'], 'value': str(entry['value'])}))
" < "${DEF_FILE}" | while IFS= read -r ENTRY_JSON; do
    ENTRY_NAME="$("${PY}" -c "import json,sys; print(json.load(sys.stdin)['name'])" <<< "${ENTRY_JSON}")"
    echo "  Setting entry: ${ENTRY_NAME}"

    # Try POST (create); on 409 fall back to PUT (update)
    HTTP_CODE=$(curl -sS -w "%{http_code}" -o "${RESP_FILE}" \
      -X POST -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${ENTRY_JSON}" \
      "${API}/${VERSIONED_NAME}/entries")

    if [[ "${HTTP_CODE}" =~ ^20[01]$ ]]; then
      echo "    Created."
    elif [[ "${HTTP_CODE}" == "409" ]]; then
      curl -sS --fail-with-body \
        -X PUT -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${ENTRY_JSON}" \
        "${API}/${VERSIONED_NAME}/entries/${ENTRY_NAME}" > /dev/null
      echo "    Updated (already existed)."
    else
      echo "    ERROR: Failed to set entry (HTTP ${HTTP_CODE}):" >&2
      cat "${RESP_FILE}" >&2 || true
      echo "" >&2
      rm -f "${RESP_FILE}"
      exit 1
    fi
  done

  echo "  Done: ${VERSIONED_NAME}"
done

rm -f "${RESP_FILE}"

if [ -d "/workspace" ]; then
  echo "${VERSION}" > /workspace/kvm_version.txt
fi

echo "KVM version ${VERSION} applied to ${ENV}."
