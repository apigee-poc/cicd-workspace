# Release notes – hello-v1

## 1.0 – first release through the full pipeline

**Released to prod:** _date_ · **Approved by:** _name_

| Item | Value |
|---|---|
| Commit on `main` | `_short id_` |
| Revision in dev / staging (`apigee-nonprod-511322`) | `_N_` |
| Revision in prod (`apigee-prod-511508`) | `_N_` |
| Bundle description | `hello-v1 \| commit _short id_ \| build _build id_` |
| Release build (`release-prod`) | `_build id_` |
| Tests | 21/21 assertions in dev, staging and prod |

### What the API does

- `GET /v1/hello?name=<letters>` returns `{"message":"Hello, <name>!"}`.
- Without `name`, it greets `World`.
- An empty or invalid `name` (not 1-30 letters) returns `400 invalid_request`.
- Any other method or path returns `404 not_found`.
- Contract: [openapi.yaml](openapi.yaml).

### Known limitations

- Runs on Apigee evaluation orgs, which are deleted 60 days after creation.
- Hostnames use nip.io (a free public DNS service), not a company domain.
- No authentication: the API is public by design for this POC.
