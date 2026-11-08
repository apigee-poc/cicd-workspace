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
| `GET /v1/hello?name=Rizk` | 200 | `{"message":"Hello, Rizk!","environment":"dev"}` |
| `GET /v1/hello/?name=Rizk` | 200 | `{"message":"Hello, Rizk!","environment":"dev"}` (trailing slash is accepted) |
| `GET /v1/hello` | 200 | `{"message":"Hello, World!","environment":"dev"}` (default name) |
| `GET /v1/hello?name=Rizk123` | 400 | `{"error":"invalid_request","message":"Query parameter 'name' must be 1-30 letters (A-Z, a-z)."}` |
| `GET /v1/hello?name=` | 400 | same as above |
| Any other method or path | 404 | `{"error":"not_found","message":"Only GET /v1/hello is supported."}` |

Sample request and response:

```
$ curl -i "http://localhost:8998/v1/hello?name=Rizk"
HTTP/1.1 200 OK
Content-Type: application/json

{"message":"Hello, Rizk!","environment":"dev"}
```

Full acceptance criteria: [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md).

## Project structure

```
cloudbuild-pr.yaml                   # PR validation: lint gate + Maven package
cloudbuild-main.yaml                 # Non-prod CD: deploy dev -> test (rollback on failure) -> promote staging -> test (rollback on failure)
cloudbuild-prod.yaml                 # Prod CD: import to prod -> deploy -> smoke test (rollback on failure)
deploy/
└── shared-pom.xml                   # Maven parent: plugins + dev/staging/prod profiles
src/main/apigee/
├── apiproxies/hello-v1/
│   ├── pom.xml                      # Maven child pom for this proxy
│   └── apiproxy/
│       ├── hello-v1.xml             # proxy descriptor
│       ├── proxies/default.xml      # ProxyEndpoint: base path, flows, no-target route
│       └── policies/
│           ├── KVM-Get-Config.xml   # PreFlow policy loading versioned KVM (hello-v1-config-<SHA>)
│           ├── AM-Extract-Name.xml  # reads ?name, defaults to "World"
│           ├── RF-Invalid-Name.xml  # 400 when name is not 1-30 letters
│           ├── AM-Hello-Response.xml# builds the 200 JSON response
│           └── RF-Not-Found.xml     # 404 for any other method/path
└── environments/
    ├── dev/
    │   ├── kvms/hello-v1-config.json # Declarative KVM definition for dev
    │   ├── deployments.json          # proxies deployed to the emulator
    │   └── *.json                    # emulator env config created by Cloud Code
    ├── staging/
    │   └── kvms/hello-v1-config.json # Declarative KVM definition for staging
    └── prod/
        └── kvms/hello-v1-config.json # Declarative KVM definition for prod
tests/
├── hello-v1.postman_collection.json # 7 requests, 21 assertions (single source of tests)
└── environments/
    ├── local.postman_environment.json    # baseUrl for the local emulator
    ├── dev.postman_environment.json      # baseUrl for Apigee dev
    ├── staging.postman_environment.json  # baseUrl for Apigee staging
    └── prod.postman_environment.json     # baseUrl for Apigee prod
scripts/
├── check-apigee-org.ps1             # read-only check: envs, instance, env groups, hostnames
├── get-deployed-revision.sh         # retrieves currently active revision in an environment
├── deploy-revision.sh               # deploys an existing revision to an environment
├── wait-for-deployment.sh           # waits for revision state to become READY
├── rollback.sh                      # rolls back to previous revision (or undeploys) on test failure
├── copy-revision.sh                 # copies revision bundle from nonprod org to prod org
└── create-versioned-kvm.sh          # provisions versioned KVMs (<name>-<SHA>) before deployment
docs/
├── ACCEPTANCE.md                    # scope, acceptance criteria, prerequisites
├── DEPLOYMENT.md                    # environments, deploy/promote commands, resources, KVM versioning
├── CONFIG_REVIEW.md                 # review of secrets and configs as code
├── apigeelint-baseline.txt          # lint before the CC004 fix
└── apigeelint-after-fix.txt         # lint after the fix (0 errors, 0 warnings)
package.json / package-lock.json     # pinned apigeelint + newman, npm scripts
```

Generated, never committed: `node_modules/`, `reports/`, `**/target/`.

## How the proxy works

1. `KVM-Get-Config` runs in the PreFlow, querying `hello-v1-config-<SHA>` (stamped at build time with `${SHORT_SHA}`).
2. The `get-hello` flow runs for `GET` on the base path (`/v1/hello`).
3. `AM-Extract-Name` copies `request.queryparam.name` into `hello.name` (default `World`).
4. `RF-Invalid-Name` runs if `hello.name` does not match `^[A-Za-z]{1,30}$` (returns 400).
5. `AM-Hello-Response` builds the 200 JSON response.
6. Catch-all `not-found` flow returns 404 for any other path or verb.

## Configuration that varies by environment

The proxy bundle itself references environment-specific settings via versioned KVMs.
What changes per environment:

| Setting | local | dev (non-prod) | staging (non-prod) | prod |
|---|---|---|---|---|
| Base URL | `http://localhost:8998` | `https://35.201.86.122.nip.io` | `https://staging.35.201.86.122.nip.io` | `https://prod.35.201.86.122.nip.io` |
| Postman environment file | `local.postman_environment.json` | `dev.postman_environment.json` | `staging.postman_environment.json` | `prod.postman_environment.json` |
| Apigee org | – (emulator) | `apigee-nonprod-511322` | `apigee-nonprod-511322` | `apigee-prod-511508` |
| Apigee environment | `dev` (emulator env) | `dev` | `staging` | `prod` |
| Maven profile | – | `-Pdev` | `-Pstaging` | `-Pprod` |
| KVM definition | – | `dev/kvms/hello-v1-config.json` | `staging/kvms/hello-v1-config.json` | `prod/kvms/hello-v1-config.json` |
| Deploy identity | none | personal account / CI service account | CI service account | CI service account |

## KVM Versioning & Automatic Rollback

Apigee X KVMs are mutable stores. To ensure deployments are safe and rollbacks are instantaneous:
- **Versioned Naming**: KVMs are named `<base-name>-<SHORT_SHA>` (e.g. `hello-v1-config-a1b2c3d`).
- **Build Stamping**: In Cloud Build, `stamp-commit` replaces `__KVM_VERSION__` in `KVM-Get-Config.xml` with the Git short SHA before packaging and importing.
- **Pre-deploy Provisioning**: `scripts/create-versioned-kvm.sh` creates the KVM and populates entries from `src/main/apigee/environments/<env>/kvms/*.json` prior to deployment.
- **Rollback on Test Failure**: If post-deployment Newman tests fail, `scripts/rollback.sh` redeploys the prior revision. Since that revision references its own versioned KVM (`hello-v1-config-<PREV_SHA>`) which is never overwritten or deleted, configuration rollback is automatic and atomic.

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

## CI/CD pipelines (Cloud Build)

Continuous integration and continuous deployment are managed via Google Cloud Build:

1. **Pull Request Validation (`cloudbuild-pr.yaml`)**:
   Runs on every pull request to `main`.
   - `npm ci`
   - Gate 1: `npm run lint` (apigeelint with 0 errors and 0 warnings)
   - Gate 3: Unit test check
   - Maven package: packages `hello-v1-1.0.zip`

2. **Non-Prod Deployment & Promotion (`cloudbuild-main.yaml`)**:
   Runs on push / merge to `main`.
   - Stamps commit SHA and KVM version into proxy bundle descriptor and policies.
   - Quality gate 1: lint.
   - Records currently active revision in `dev`.
   - Creates versioned KVM (`create-versioned-kvm.sh ${_ORG} dev ${SHORT_SHA}`).
   - Deploys new revision to `dev` and waits until `READY`.
   - Runs post-deploy tests (`npm run test:dev`). If tests fail, automatically rolls back `dev` to the previous revision (which already points to its own versioned KVM).
   - If `dev` passes, records currently active revision in `staging`.
   - Creates versioned KVM in `staging`.
   - Promotes the tested revision to `staging` and waits until `READY`.
   - Runs post-deploy tests (`npm run test:staging`). If tests fail, automatically rolls back `staging` to previous revision.

3. **Production Deployment (`cloudbuild-prod.yaml`)**:
   Manual trigger with approval.
   - Identifies and exports the tested revision from staging.
   - Records currently active revision in `prod`.
   - Copies bundle to prod org.
   - Extracts commit SHA from bundle description.
   - Creates versioned KVM in `prod` with prod-specific values.
   - Deploys the revision to `prod`.
   - Runs smoke tests (`npm run test:prod`). If smoke tests fail, automatically rolls back `prod` to previous revision.
