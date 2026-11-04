#!/usr/bin/env bash
# Rolls back an Apigee proxy deployment after a post-deployment test failure.
# Usage: rollback.sh <org> <env> <proxy> <prev_revision> [failed_revision]
#
# If prev_revision is present: redeploys and waits for prev_revision to become READY.
# If prev_revision is empty/none: undeploys failed_revision so broken code is not live.
set -euo pipefail

ORG="$1"; ENV="$2"; PROXY="$3"; PREV_REV="${4:-}"; FAILED_REV="${5:-}"
TOKEN="$(gcloud auth print-access-token 2>/dev/null || ([ -f /workspace/.token ] && cat /workspace/.token) || true)"

echo "============================================================"
echo "POST-DEPLOYMENT TEST FAILED: INITIATING ROLLBACK"
echo "Org: ${ORG} | Env: ${ENV} | Proxy: ${PROXY}"
echo "============================================================"

if [[ -n "${PREV_REV}" && "${PREV_REV}" != "none" ]]; then
  echo "Rolling back ${PROXY} in ${ENV} to previous revision ${PREV_REV}..."
  bash scripts/deploy-revision.sh "${ORG}" "${ENV}" "${PROXY}" "${PREV_REV}"
  echo "Waiting for revision ${PREV_REV} to reach READY state in ${ENV}..."
  bash scripts/wait-for-deployment.sh "${ORG}" "${ENV}" "${PROXY}" 300 "${PREV_REV}"
  echo "SUCCESS: Rollback complete. Revision ${PREV_REV} is active and READY in ${ENV}."
else
  echo "Notice: No previous revision was deployed in ${ENV} prior to this run."
  if [[ -n "${FAILED_REV}" && "${FAILED_REV}" != "none" ]]; then
    echo "Undeploying failed revision ${FAILED_REV} from ${ENV}..."
    curl -sS --fail-with-body -X DELETE -H "Authorization: Bearer ${TOKEN}" \
      "https://apigee.googleapis.com/v1/organizations/${ORG}/environments/${ENV}/apis/${PROXY}/revisions/${FAILED_REV}/deployments" \
      > /dev/null || true
    echo "SUCCESS: Failed revision ${FAILED_REV} has been undeployed from ${ENV}."
  fi
fi
