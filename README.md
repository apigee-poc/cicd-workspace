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
.github/workflows/
└── ci.yml                           # CI: lint gate, Maven package, bundle artifact
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
    ├── local.postman_environment.json  # baseUrl for the local emulator
    └── dev.postman_environment.json    # baseUrl for Apigee dev
scripts/
└── check-apigee-org.ps1             # read-only check: envs, instance, env groups, hostnames
docs/
├── ACCEPTANCE.md                    # scope, acceptance criteria, prerequisites
├── DEPLOYMENT.md                    # environments, deploy/promote commands, resources
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

| Setting | local | dev (non-prod) | staging (non-prod) |
|---|---|---|---|
| Base URL | `http://localhost:8998` | `https://35.201.86.122.nip.io` | `https://staging.35.201.86.122.nip.io` |
| Postman environment file | `local.postman_environment.json` | `dev.postman_environment.json` | `staging.postman_environment.json` (Day 4) |
| Apigee org | – (emulator) | `apigee-nonprod-511322` | `apigee-nonprod-511322` |
| Apigee environment | `dev` (emulator workspace env) | `dev` | `staging` |
| Maven profile | – | `-Pdev` | `-Pstaging` |
| Deploy identity | none | your Google account (manual), CI service account (Day 4) | CI service account (Day 4) |

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

## CI pipeline

`.github/workflows/ci.yml` runs on every pull request to `main`, every push to `main`,
and on demand (Actions tab → CI → Run workflow).

| Step | Gate / output |
|---|---|
| `npm ci` | installs the exact tool versions from `package-lock.json` |
| `npm run lint` | gate 1: any lint error or warning fails the run |
| JavaScript unit tests | not applicable (no JavaScript) |
| Maven package | builds `hello-v1-1.0.zip` |
| Artifacts | `hello-v1-bundle-<commit>` (zip + `build-info.json` with commit, branch, run) and `reports-<commit>` (lint report), kept 30 days |

The workflow has read-only repo access and no cloud credentials: it validates, it does not deploy.
Deployment is added as a separate stage on Day 4.

Working rule: every change goes through a pull request, and CI must be green before merging.

## Roadmap

- **Day 1** – proxy, local tests, repository ✅
- **Day 2** – apigeelint, Postman/Newman tests, quality gates, Maven packaging ✅
- **Day 3** – deploy to non-prod `dev` (revision 1, tag `deploy-dev-r1`), post-deploy tests, GitHub Actions CI ✅
- **Day 4** – CI deployment stage, post-deploy tests, promotion to `staging`
- change for test pr