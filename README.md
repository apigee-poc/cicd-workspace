# hello-v1 – Apigee CI/CD POC

A minimal Apigee API proxy used to practise a full CI/CD flow:
local development → lint → automated tests → packaging → deployment → promotion.

The proxy exposes one endpoint, `GET /v1/hello?name=...`, and returns a JSON greeting.
It has **no backend target**, so its behaviour is fully predictable.

## Prerequisites

Docker, VS Code + Cloud Code, Git, Node.js + npm, Java 17, Maven 3.9.
Versions in use are recorded in [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md).

## Quick start (local emulator)

1. Clone the repo and install the npm tools (once):

   ```powershell
   npm install
   ```

2. Open the folder in VS Code. In **Cloud Code → Apigee**, open it as the Apigee workspace
   (the workspace root is `src/main/apigee`).
3. In the **Apigee Emulators** panel, start an emulator container
   (note its traffic port; the default is `8998`).
4. Under **Apigee workspace → environments → dev**, click **Deploy to Apigee Emulator**.
5. Call the API:

   ```powershell
   curl.exe -i "http://localhost:8998/v1/hello?name=Rizk"
   ```

6. Run the checks:

   ```powershell
   npm run lint         # gate 1: static analysis
   npm run test:local   # gate 2: functional tests against the emulator
   npm run package      # build the deployable bundle with Maven
   ```

   If your emulator uses a different port, change `baseUrl` in
   `tests/environments/local.postman_environment.json` (don't commit that change).

   After a deploy to Apigee `dev`, run the same tests against it:

   ```powershell
   npm run test:dev     # post-deploy tests against https://35.201.86.122.nip.io
   ```

7. Or use Postman: import `tests/hello-v1.postman_collection.json` and
   `tests/environments/local.postman_environment.json`.

## Endpoint behaviour

| Request | Status | Response body |
|---|---|---|
| `GET /v1/hello?name=Rizk` | 200 | `{"message":"Hello, Rizk!"}` |
| `GET /v1/hello/?name=Rizk` | 200 | `{"message":"Hello, Rizk!"}` (trailing slash is accepted) |
| `GET /v1/hello` | 200 | `{"message":"Hello, World!"}` (default name) |
| `GET /v1/hello?name=Rizk123` | 400 | `{"error":"invalid_request","message":"Query parameter 'name' must be 1-30 letters (A-Z, a-z)."}` |
| `GET /v1/hello?name=` | 400 | same as above |
| Any other method or path | 404 | `{"error":"not_found","message":"Only GET /v1/hello is supported."}` |

Sample request and response:

```
$ curl -i "http://localhost:8998/v1/hello?name=Rizk"
HTTP/1.1 200 OK
Content-Type: application/json

{"message":"Hello, Rizk!"}
```

Full acceptance criteria: [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md).

## Project structure

```
cloudbuild-pr.yaml                   # Cloud Build: PR validation (lint + package)
cloudbuild-main.yaml                 # Cloud Build: on merge, deploy dev -> test -> staging -> test
cloudbuild-prod.yaml                 # Cloud Build: manual prod release with approval
deploy/
└── shared-pom.xml                   # Maven parent: plugins + dev/staging/prod profiles
src/main/apigee/
├── apiproxies/hello-v1/
│   ├── pom.xml                      # Maven child pom for this proxy
│   └── apiproxy/
│       ├── hello-v1.xml             # proxy descriptor
│       ├── proxies/default.xml      # ProxyEndpoint: base path, flows, no-target route
│       └── policies/
│           ├── AM-Extract-Name.xml  # reads ?name, defaults to "World"
│           ├── RF-Invalid-Name.xml  # 400 when name is not 1-30 letters
│           ├── AM-Hello-Response.xml# builds the 200 JSON response
│           └── RF-Not-Found.xml     # 404 for any other method/path
└── environments/dev/
    ├── deployments.json             # proxies deployed to the emulator
    └── *.json                       # emulator env config created by Cloud Code
tests/
├── hello-v1.postman_collection.json # 7 requests, 21 assertions (single source of tests)
└── environments/
    ├── local.postman_environment.json    # baseUrl for the local emulator
    ├── dev.postman_environment.json      # baseUrl for Apigee dev
    ├── staging.postman_environment.json  # baseUrl for Apigee staging
    └── prod.postman_environment.json     # baseUrl for Apigee prod (smoke tests)
tests/perf/
└── baseline.js                      # k6 baseline, non-prod only
scripts/
├── check-apigee-org.ps1             # read-only check: envs, instance, env groups, hostnames
├── wait-for-deployment.sh           # waits until a revision is READY in an environment
├── deploy-revision.sh               # deploys an existing revision (promotion)
└── copy-revision.sh                 # exports a revision from one org, imports it into another
docs/
├── ACCEPTANCE.md                    # scope, acceptance criteria, prerequisites
├── DEPLOYMENT.md                    # environments, pipelines, identities, commands
├── CONFIG_REVIEW.md                 # configuration and secret review, perf baseline
├── RELEASE_NOTES.md                 # release notes for hello-v1
├── DEMO.md                          # demo checklist, retrospective, next-steps backlog
├── openapi.yaml                     # API contract for hello-v1
├── apigeelint-baseline.txt          # lint before the CC004 fix
└── apigeelint-after-fix.txt         # lint after the fix (0 errors, 0 warnings)
package.json / package-lock.json     # pinned apigeelint + newman, npm scripts
```

Generated, never committed: `node_modules/`, `reports/`, `**/target/`.

## How the proxy works

1. The `get-hello` flow runs only for `GET` on the base path itself (with or without a trailing slash).
2. `AM-Extract-Name` copies `request.queryparam.name` into `hello.name`;
   if the parameter is missing, it uses `World`.
3. `RF-Invalid-Name` runs only when `hello.name` doesn't match `^[A-Za-z]{1,30}$`
   and returns a 400.
4. `AM-Hello-Response` builds the 200 JSON response.
5. Every other request falls into the `not-found` flow and gets a 404.

## Configuration that varies by environment

The proxy bundle itself has no environment-specific values (no target servers, KVMs or secrets).
What changes per environment is only *where* it runs:

| Setting | local | dev | staging | prod |
|---|---|---|---|---|
| Base URL | `http://localhost:8998` | `https://35.201.86.122.nip.io` | `https://staging.35.201.86.122.nip.io` | `https://136.68.4.183.nip.io` |
| Postman environment file | `local` | `dev` | `staging` | `prod` |
| Apigee org | – (emulator) | `apigee-nonprod-511322` | `apigee-nonprod-511322` | `apigee-prod-511508` |
| Apigee environment | `dev` (emulator workspace env) | `dev` | `staging` | `prod` |
| How it gets deployed | Cloud Code | `main-deploy-nonprod` (new revision) | `main-deploy-nonprod` (same revision as dev) | `release-prod` (staging revision copied, after approval) |
| Deploy identity | none | `cb-deploy-nonprod` | `cb-deploy-nonprod` | `cb-deploy-prod` |

## Emulator limitations (recorded during Day 1)

- Runs only on `localhost:<port>`; there are no environment groups or hostnames like in Apigee X.
- No analytics or monitoring dashboards.
- POST/PUT requests without a body and without `Content-Length` are rejected by the
  Apigee runtime with 411 before reaching the proxy. Clients must send
  `Content-Length: 0` (Postman does this automatically; curl needs `--data ""`).
- Emulator version used: 1.9.

## Unit tests

Not applicable: the proxy has no JavaScript resources (only AssignMessage and
RaiseFault policies, no `resources/jsc`). Its logic is fully covered by the
functional tests in `tests/hello-v1.postman_collection.json`.

If a JavaScript policy is added later, add unit tests with Mocha + Chai,
measure coverage with nyc, and add a coverage gate (see Quality gates).

## Quality gates

Every gate must pass. If any gate fails, the pipeline stops and nothing is deployed.

| # | Gate | Command | Passes when |
|---|---|---|---|
| 1 | Static analysis | `npm run lint` | 0 errors and 0 warnings (`--maxWarnings 0`) |
| 2 | Functional tests | `npm run test:local` (CI: same collection against the deployed env) | All Newman assertions pass |
| 3 | JS unit test coverage | — | Not applicable (no JavaScript in the proxy) |

Rules:
- A warning is treated as a failure. To accept a warning, fix it or document an
  exception here with the reason. Do not disable rules broadly.
- Tool versions are pinned in `package-lock.json`, so local and CI results match.
- Deployment (Day 3+) only runs after gates 1 and 2 pass.

## Packaging and deployment

Package the proxy bundle (no call to Apigee):

    npm run package

Output: `src/main/apigee/apiproxies/hello-v1/target/hello-v1-1.0.zip`.
Environments, deploy and promote commands: see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

## CI/CD pipeline (Cloud Build)

All pipelines run in Cloud Build in project `ci-cd-511313` (region `europe-west1`),
connected to this GitHub repo through the Cloud Build GitHub App.

```
feature branch -> pull request -> [pr-validate]          lint -> package           (required check)
                       merge to main -> [main-deploy-nonprod] stamp commit -> lint -> deploy dev (revision N)
                                                          -> test dev -> deploy N to staging -> test staging
                       manual + approval -> [release-prod]  copy staging revision to prod org -> deploy prod -> smoke test
```

| Trigger | Starts on | Config | Runs as | Can touch |
|---|---|---|---|---|
| `pr-validate` | pull request to `main` | `cloudbuild-pr.yaml` | `cb-validate` | nothing in Apigee |
| `main-deploy-nonprod` | push to `main` | `cloudbuild-main.yaml` | `cb-deploy-nonprod` | `dev`, `staging` |
| `release-prod` | manual run, then approval | `cloudbuild-prod.yaml` | `cb-deploy-prod` | `prod` (read-only on non-prod) |

Rules:
- Every change goes through a pull request; `pr-validate (ci-cd-511313)` is the required check.
- The bundle is built once per merge. Staging gets the same revision as dev; prod gets the exact
  bundle exported from staging. Nothing is rebuilt for a later environment.
- Each bundle carries `hello-v1 | commit <id> | build <id>` in its description, in every org.
- Any failing step stops the pipeline: staging is only touched after dev passes, and prod is
  only released by hand, after approval, from what passed staging.

Details, identities and manual commands: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

## Roadmap

- **Day 1** – proxy, local tests, repository ✅
- **Day 2** – apigeelint, Postman/Newman tests, quality gates, Maven packaging ✅
- **Day 3** – deploy to non-prod `dev` (revision 1, tag `deploy-dev-r1`), post-deploy tests, GitHub Actions CI ✅
- **Day 4** – CI/CD moved to Cloud Build: PR validation, automatic dev → staging release, approved prod release, config and secret review, k6 baseline ✅

Plan change (Day 4): the original plan deployed with GitHub Actions and kept production out of scope.
We moved all pipelines to Cloud Build in `ci-cd-511313` and added a prod release with manual approval.
See [docs/DEMO.md](docs/DEMO.md) for the retrospective and next steps.
