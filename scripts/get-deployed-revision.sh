#!/usr/bin/env bash
# Retrieves the revision of an API proxy currently deployed in an environment.
# Usage: get-deployed-revision.sh <org> <env> <proxy> [output_file]
# Writes the deployed revision number (e.g. "12") or empty string if not deployed.
set -euo pipefail

ORG="$1"; ENV="$2"; PROXY="$3"; OUT_FILE="${4:-}"
PY="$(command -v python3 || gcloud info --format='value(basic.python_location)')"
TOKEN="$(gcloud auth print-access-token 2>/dev/null || ([ -f /workspace/.token ] && cat /workspace/.token) || true)"
BASE="https://apigee.googleapis.com/v1/organizations/${ORG}/environments/${ENV}/apis/${PROXY}"

RESP="$(curl -sS -H "Authorization: Bearer ${TOKEN}" "${BASE}/deployments" 2>/dev/null || echo "{}")"

REV="$(echo "${RESP}" | "${PY}" -c '
import json, sys
try:
    data = json.load(sys.stdin)
    deployments = data.get("deployments", [])
    revs = [int(x["revision"]) for x in deployments if "revision" in x]
    print(max(revs) if revs else "")
except Exception:
    print("")
')"

echo "Currently active revision in ${ENV}: ${REV:-none}" >&2

if [[ -n "${OUT_FILE}" ]]; then
  echo "${REV}" > "${OUT_FILE}"
else
  echo "${REV}"
fi
