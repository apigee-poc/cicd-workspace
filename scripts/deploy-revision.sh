#!/usr/bin/env bash
# Deploys an EXISTING revision of a proxy to an environment (no new import).
# Used to promote the revision that passed in dev to staging.
# Usage: deploy-revision.sh <org> <env> <proxy> <revision>
set -euo pipefail

ORG="$1"; ENV="$2"; PROXY="$3"; REV="$4"
if [[ -z "${REV}" ]]; then
  echo "No revision given" >&2
  exit 1
fi

TOKEN="$(gcloud auth print-access-token)"
echo "Deploying ${PROXY} revision ${REV} to ${ENV} in ${ORG}"
curl -sS --fail-with-body -X POST -H "Authorization: Bearer ${TOKEN}" \
  "https://apigee.googleapis.com/v1/organizations/${ORG}/environments/${ENV}/apis/${PROXY}/revisions/${REV}/deployments?override=true" \
  > /dev/null
echo "Deployment requested"
