# Configuration and secret review

Reviewed on: 2026-10-15 · Reviewed by: _name_

## 1. What the proxy needs per environment

| Item | Used? | Where the value lives | Notes |
|---|---|---|---|
| Target servers | No | – | No-target proxy |
| KVMs | No | – | No runtime configuration |
| Secrets (API keys, passwords, certificates) | No | – | Nothing to store in Secret Manager |
| Environment-specific bundle config (`config.json`) | No | – | The same bundle runs in every environment |
| Base URL per environment | Yes | `tests/environments/*.postman_environment.json` | Not secret |
| Apigee org / environment per stage | Yes | `deploy/shared-pom.xml` profiles, `cloudbuild-*.yaml` substitutions | Not secret |

## 2. Credentials: where they are and are not

| Credential | How it is obtained | Stored anywhere? |
|---|---|---|
| Local manual deploy | `gcloud auth print-access-token` (personal account) | No, passed on the command line at run time |
| Cloud Build, PR | `cb-validate` service account | No key exists; it has no Apigee access |
| Cloud Build, non-prod | `cb-deploy-nonprod`, token from the build environment | Only in `/workspace/.token` during the build; discarded with the build |
| Cloud Build, prod | `cb-deploy-prod`, token from the build environment | Never written to a file |
| GitHub to Cloud Build | GitHub App installation, token in Secret Manager (managed by Cloud Build) | Secret Manager in `ci-cd-511313` |

No service account keys were created. No credential is in Git, in the build config, or in the Postman files.

## 3. Checks performed

- [x] Secret scan of the full Git history (gitleaks, 30 commits): no leaks found
- [x] Manual search of history: `apikey`, `password`, `Bearer ya29` – no matches.
      `Authorization` – 5 commits, all scripts that build the header from a runtime `$TOKEN`; no values
- [ ] No OAuth token (`ya29.`) printed in Cloud Build logs: main-deploy-nonprod _N_, release-prod _N_
- [x] Postman collection and environment files contain no auth settings
- [x] `.gitignore` excludes `.env`, keys, `node_modules/`, `reports/`, `target/`

## 4. Manual vs automated

| Resource | Created by | As code? |
|---|---|---|
| Proxy bundle, policies | Developers, Git | ✅ |
| Tests (Postman collection, environment files) | Git | ✅ |
| Lint and quality gates | `package.json`, `cloudbuild-pr.yaml` | ✅ |
| Build, deploy, promote, prod release steps | `cloudbuild-*.yaml`, `scripts/*.sh` | ✅ |
| Maven environment profiles | `deploy/shared-pom.xml` | ✅ |
| Apigee orgs, environments, instance attachments | Console wizard + API (manual) | ❌ |
| Environment groups, nip.io hostnames, TLS certificates | gcloud / API (manual, documented in the environments guide) | ❌ |
| Service accounts and IAM roles | gcloud (manual) | ❌ |
| Cloud Build triggers and GitHub connection | gcloud / console (manual) | ❌ |
| GitHub branch ruleset | GitHub settings (manual) | ❌ |

Next step for a real project: define the ❌ rows with infrastructure as code
(for example Terraform), so environments can be recreated and reviewed like the proxy.

## 5. Performance baseline (non-prod)

Run on 2026-10-15 with k6 (`tests/perf/baseline.js`) against `dev` (`https://35.201.86.122.nip.io`):
5 virtual users, 30 s, 0.5 s pause between requests.

| Metric | Result | Threshold |
|---|---|---|
| Requests | 220 (7.2/s) | – |
| Error rate | 0.00% | < 1% ✓ |
| p95 latency | 191 ms | < 1000 ms ✓ |
| Avg / min / max | 177 / 167 / 202 ms | – |
| Checks (status + body) | 440 / 440 | – |

This is a small baseline on an evaluation org, measured from one laptop.
It does not describe production capacity. Never run this test against prod.
