# hello-v1 – Apigee CI/CD POC

A minimal Apigee API proxy used to practise a full CI/CD flow:
local development → lint → automated tests → packaging → deployment → promotion.

The proxy exposes one endpoint, `GET /v1/hello?name=...`, and returns a JSON greeting.
It has **no backend target**, so its behaviour is fully predictable.

## Quick start (local emulator)

1. Clone the repo and open the folder in VS Code.
2. In **Cloud Code → Apigee**, open this folder as the Apigee workspace
   (the workspace root is `src/main/apigee`).
3. In the **Apigee Emulators** panel, start an emulator container
   (note its traffic port; the default is `8998`).
4. Under **Apigee workspace → environments → dev**, click **Deploy to Apigee Emulator**.
5. Call the API:

   ```bash
   curl -i "http://localhost:8998/v1/hello?name=Asmaa"
   ```

6. Run the local tests.

   Windows (PowerShell, using Git Bash):

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" tests/local-smoke.sh
   # different emulator port:
   & "C:\Program Files\Git\bin\bash.exe" -c "BASE_URL=http://localhost:9000 ./tests/local-smoke.sh"
   ```

   Linux / macOS / Git Bash:

   ```bash
   ./tests/local-smoke.sh
   BASE_URL=http://localhost:9000 ./tests/local-smoke.sh
   ```

   Note: in PowerShell, plain `bash` may start WSL instead of Git Bash and fail.

7. Or use Postman: import `tests/hello-v1.postman_collection.json`.
   It uses a `{{baseUrl}}` collection variable (default `http://localhost:8998`).

## Endpoint behaviour

| Request | Status | Response body |
|---|---|---|
| `GET /v1/hello?name=Asmaa` | 200 | `{"message":"Hello, Asmaa!"}` |
| `GET /v1/hello` | 200 | `{"message":"Hello, World!"}` (default name) |
| `GET /v1/hello?name=Asmaa123` | 400 | `{"error":"invalid_request","message":"Query parameter 'name' must be 1-30 letters (A-Z, a-z)."}` |
| `GET /v1/hello?name=` | 400 | same as above |
| Any other method or path | 404 | `{"error":"not_found","message":"Only GET /v1/hello is supported."}` |

Sample request and response:

```
$ curl -i "http://localhost:8998/v1/hello?name=Asmaa"
HTTP/1.1 200 OK
Content-Type: application/json

{"message":"Hello, Asmaa!"}
```

Full acceptance criteria: [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md).

## Project structure

```
src/main/apigee/
├── apiproxies/hello-v1/apiproxy/
│   ├── hello-v1.xml                 # proxy descriptor
│   ├── proxies/default.xml          # ProxyEndpoint: base path, flows, no-target route
│   └── policies/
│       ├── AM-Extract-Name.xml      # reads ?name, defaults to "World"
│       ├── RF-Invalid-Name.xml      # 400 when name is not 1-30 letters
│       ├── AM-Hello-Response.xml    # builds the 200 JSON response
│       └── RF-Not-Found.xml         # 404 for any other method/path
└── environments/dev/
    ├── deployments.json             # proxies deployed to the emulator
    └── *.json                       # emulator env config created by Cloud Code (empty for now)
tests/
├── local-smoke.sh                   # repeatable local tests (exit code 1 on failure)
└── hello-v1.postman_collection.json # same 6 requests for Postman (baseUrl variable)
docs/
└── ACCEPTANCE.md                    # scope, acceptance criteria, prerequisites
```

## How the proxy works

1. The `get-hello` flow runs only for `GET` on the base path itself.
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
| Base URL | `http://localhost:8998` | env group hostname for `dev` | env group hostname for `staging` |
| Apigee org | – (emulator) | non-prod project ID | non-prod project ID |
| Apigee environment | `dev` (emulator workspace env) | `dev` | `staging` |
| Deploy identity | none | CI service account (Day 3–4) | CI service account (Day 4) |

## Emulator limitations (recorded during Day 1)

- Runs only on `localhost:<port>`; there are no environment groups or hostnames like in Apigee X.
- No analytics or monitoring dashboards.
- POST/PUT requests without a body and without `Content-Length` are rejected by the
  Apigee runtime with 411 before reaching the proxy. Clients must send
  `Content-Length: 0` (Postman does this automatically; curl needs `--data ""`).
- Emulator version used: _fill in from the Cloud Code emulator panel_.

## Roadmap

- **Day 1** – proxy, local tests, repository ✅
- **Day 2** – apigeelint, Postman/Newman tests, Maven packaging
- **Day 3** – deploy to non-prod `dev`, GitHub Actions CI
- **Day 4** – CI deployment stage, post-deploy tests, promotion to `staging`