#!/usr/bin/env bash
# Copies an existing proxy revision from one Apigee org to another, unchanged.
# Exports the bundle zip from the source org and imports it into the target org.
# Usage: copy-revision.sh <source_org> <revision> <target_org> <proxy>
# Writes: bundle.zip, bundle_description.txt, imported_revision.txt
set -euo pipefail

SRC_ORG="$1"; REV="$2"; DST_ORG="$3"; PROXY="$4"
if [[ -z "${REV}" ]]; then
  echo "No source revision given" >&2
  exit 1
fi
API="https://apigee.googleapis.com/v1/organizations"
TOKEN="$(gcloud auth print-access-token)"

# Record what is being released (the description carries the commit stamp)
curl -sS --fail-with-body -H "Authorization: Bearer ${TOKEN}" \
  "${API}/${SRC_ORG}/apis/${PROXY}/revisions/${REV}" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("description",""))' > bundle_description.txt
echo "Source: ${SRC_ORG} ${PROXY} revision ${REV} -> $(cat bundle_description.txt)"

# Export the exact bundle
curl -sS --fail-with-body -H "Authorization: Bearer ${TOKEN}" \
  "${API}/${SRC_ORG}/apis/${PROXY}/revisions/${REV}?format=bundle" -o bundle.zip
echo "Exported bundle: $(wc -c < bundle.zip) bytes"

# Import it into the target org as a new revision
NEW_REV="$(curl -sS --fail-with-body -X POST -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@bundle.zip" \
  "${API}/${DST_ORG}/apis?action=import&name=${PROXY}" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["revision"])')"

echo "${NEW_REV}" > imported_revision.txt
echo "Imported into ${DST_ORG} as ${PROXY} revision ${NEW_REV}"
