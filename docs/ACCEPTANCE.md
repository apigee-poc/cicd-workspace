# Scope, acceptance criteria and prerequisites

## Scope

One simple API proxy, `hello-v1`, used only to learn the CI/CD flow.
It has no backend target: the proxy builds the response itself, so results are deterministic.

| Item | Value |
|---|---|
| Proxy name | `hello-v1` |
| Base path | `/v1/hello` |
| Local runtime | Apigee Emulator (Cloud Code for VS Code), workspace environment `dev` |
| Integration target (Day 3) | Apigee eval org `apigee-nonprod-511322`, environment `dev` |
| Promotion target (Day 4) | Same org, environment `staging` |

## Acceptance criteria

| # | Request | Expected status | Expected body |
|---|---|---|---|
| AC1 | `GET /v1/hello?name=Rizk` | 200 | `{"message":"Hello, Rizk!"}` |
| AC2 | `GET /v1/hello/?name=Rizk` (trailing slash) | 200 | `{"message":"Hello, Rizk!"}` |
| AC3 | `GET /v1/hello` (no `name`) | 200 | `{"message":"Hello, World!"}` |
| AC4 | `GET /v1/hello?name=Rizk123` (not letters only) | 400 | `{"error":"invalid_request", ...}` |
| AC5 | `GET /v1/hello?name=` (empty) | 400 | `{"error":"invalid_request", ...}` |
| AC6 | Any other method or path, e.g. `POST /v1/hello`, `GET /v1/hello/extra` | 404 | `{"error":"not_found", ...}` |
| AC7 | All responses above | – | `Content-Type: application/json` |

Validation rule: `name` must be 1–30 letters (`A–Z`, `a–z`). Restricting the input to letters also
means the value can be safely placed inside the JSON response.

Every criterion is covered by `tests/hello-v1.postman_collection.json` (7 requests, 21 assertions).

## Prerequisites checklist

| Done | Tool | Version in use | Needed for |
|---|---|---|---|
| [x] | Docker | _fill in: `docker --version`_ | Apigee Emulator |
| [x] | VS Code + Cloud Code | – | Workspace, emulator deploy |
| [x] | Apigee Emulator | 1.9 (traffic port 8998) | Local runtime |
| [x] | Git | _fill in: `git --version`_ | Source control |
| [x] | Node.js + npm | _fill in: `node -v` / `npm -v`_ | apigeelint 2.85.1, Newman 6.2.3 |
| [x] | Java | Temurin 17.0.20.1 | Maven |
| [x] | Maven | 3.9.9 | Apigee Deploy Maven Plugin 2.5.2 |
| [x] | GitHub access | `apigee-poc/cicd-workspace` | Repo |
| [ ] | GCP access to `apigee-nonprod-511322` | – | Day 3 deployment |

## Day 1 checkpoint ✅

- [x] Proxy deployed from the workspace to the emulator
- [x] All local tests green
- [x] Stable baseline committed and pushed (tag `day1-baseline`)
- [x] Blockers for Day 2 listed

## Day 2 checkpoint ✅

- [x] apigeelint pinned, `npm run lint` fails on any warning (`--maxWarnings 0`)
- [x] CC004 fixed: simplified condition, behaviour locked by the trailing-slash test
      (reports: `docs/apigeelint-baseline.txt`, `docs/apigeelint-after-fix.txt`)
- [x] Postman collection with assertions; `npm run test:local` runs it with Newman (JUnit report)
- [x] Failing tests give a non-zero exit code
- [x] JS unit tests: not applicable (no JavaScript), documented in README
- [x] Quality gates documented in README
- [x] `npm run package` builds `hello-v1-1.0.zip` with the Apigee Deploy Maven Plugin
- [x] Deployment config documented in `docs/DEPLOYMENT.md`
- [x] Day 2 baseline tagged (`day2-baseline`)

### Blockers / prerequisites for Day 3 (resolved)

- [x] Apigee eval org in `apigee-nonprod-511322` with external access
- [x] Environments `dev` and `staging`, each with its own environment group and hostname
- [x] Own account can deploy to the non-prod org

## Day 3 checkpoint ✅

- [x] Non-prod target verified (`scripts/check-apigee-org.ps1`)
- [x] Deployment identities and roles documented in `docs/DEPLOYMENT.md`
- [x] Proxy deployed to `dev` with Maven: revision 1, tag `deploy-dev-r1`
- [x] Post-deploy tests: `npm run test:dev`, 21/21 assertions passed on Apigee `dev`
- [x] Failure handling: a deliberately wrong expectation failed the run (exit code 1); restored with `git restore`, green again
- [x] CI workflow `.github/workflows/ci.yml`: lint gate, Maven package, bundle + `build-info.json` artifact
- [x] Red run: PR with CC004 reintroduced, CI failed at the lint step, not merged
- [x] Green run: PR #2 merged, CI on `main` green, `build-info.json` commit matches `main`
- [x] Day 3 baseline tagged (`day3-baseline`)

## Day 4 checkpoint

Plan change: the original plan used GitHub Actions and kept production out of scope.
Day 4 moved all pipelines to Cloud Build in `ci-cd-511313` and added a prod release with approval.
Workload Identity Federation was not needed, because Cloud Build runs inside Google Cloud.

- [x] Cloud Build setup: GitHub connection, one service account per trigger, least-privilege roles
- [x] `pr-validate`: lint + package on every PR, required check in GitHub
- [ ] GitHub Actions `ci.yml` removed after the Cloud Build check became required
- [x] `main-deploy-nonprod`: deploy dev → test → deploy the same revision to staging → test
- [x] Commit stamp in every revision description
- [ ] `release-prod`: approval → copy staging revision to prod org → deploy → smoke test (result in `docs/RELEASE_NOTES.md`)
- [x] Configuration and secret review (`docs/CONFIG_REVIEW.md`)
- [x] k6 baseline on dev: p95 191 ms, 0% errors
- [x] API contract (`docs/openapi.yaml`), release notes, demo checklist and backlog (`docs/DEMO.md`)
- [ ] Final clean run traced end to end (commit → revisions → test results)
- [ ] Day 4 baseline tagged (`day4-baseline`)
