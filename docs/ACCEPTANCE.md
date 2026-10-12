# Day 1 – Scope, acceptance criteria and prerequisites

## Scope

One simple API proxy, `hello-v1`, used only to learn the CI/CD flow.
It has no backend target: the proxy builds the response itself, so results are deterministic.

| Item | Value |
|---|---|
| Proxy name | `hello-v1` |
| Base path | `/v1/hello` |
| Local runtime | Apigee Emulator (Cloud Code for VS Code), workspace environment `dev` |
| Later integration target (Day 3) | Apigee eval org in the non-prod project, environment `dev` |
| Later promotion target (Day 4) | Same org, environment `staging` |

## Acceptance criteria

| # | Request | Expected status | Expected body |
|---|---|---|---|
| AC1 | `GET /v1/hello?name=Asmaa` | 200 | `{"message":"Hello, Asmaa!"}` |
| AC2 | `GET /v1/hello` (no `name`) | 200 | `{"message":" Hello, World!"}` |
| AC3 | `GET /v1/hello?name=Asmaa123` (not letters only) | 400 | `{"error":"invalid_request", ...}` |
| AC4 | `GET /v1/hello?name=` (empty) | 400 | `{"error":"invalid_request", ...}` |
| AC5 | Any other method or path, e.g. `POST /v1/hello`, `GET /v1/hello/extra` | 404 | `{"error":"not_found", ...}` |
| AC6 | All responses above | – | `Content-Type: application/json` |

Validation rule: `name` must be 1–30 letters (`A–Z`, `a–z`). Restricting the input to letters also
means the value can be safely placed inside the JSON response.

## Prerequisites checklist

Run each command and tick the box when it works.

| Done | Tool | Check command | Notes |
|---|---|---|---|
| [ ] | Docker | `docker --version` and `docker ps` | Docker must be running for the emulator |
| [ ] | Node.js + npm | `node -v` / `npm -v` | LTS version (needed on Day 2 for apigeelint/Newman) |
| [ ] | Java | `java -version` | Needed on Day 2 for Maven |
| [ ] | Maven | `mvn -v` | Needed on Day 2 for the Apigee Deploy Maven Plugin |
| [ ] | Git | `git --version` | |
| [ ] | VS Code + Cloud Code | Cloud Code extension installed, Apigee view visible | |
| [ ] | Apigee Emulator | Emulator container created and started from Cloud Code | Note the traffic port (default 8998) |
| [ ] | curl / Postman | `curl --version` | |
| [ ] | GitHub access | Can create a repo and push | |
| [ ] | GCP access (for Day 3) | `gcloud auth list`, access to the non-prod project | Not needed for Day 1 |

## Day 1 checkpoint

- [ ] Proxy redeployed from the workspace to the emulator
- [ ] `./tests/hello-v1.postman_collection.json` passes (all tests green)
- [ ] Stable baseline committed and pushed
- [ ] Blockers for Day 2 listed below

### Blockers / notes for Day 2

- apigeelint baseline already shows one warning to handle on Day 2:
  `CC004` (condition with many terms) on the `get-hello` flow condition.
- change the CC004 blocker line to "CC004 fixed: simplified condition, behaviour locked by the trailing-slash test."
  
- _Add any other blockers here._