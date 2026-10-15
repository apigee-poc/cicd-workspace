# Configuration and secret review

Reviewed on: _date_ · Reviewed by: _name_

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

- [ ] Secret scan of the full Git history (gitleaks): _result_
- [ ] Manual search of history for `apikey`, `token`, `password`, `Authorization`: _result_
- [ ] No OAuth token (`ya29.`) printed in Cloud Build logs (dev/staging and prod builds): _result_
- [ ] Postman collection and environment files contain no auth settings: _result_
- [ ] `.gitignore` excludes `.env`, keys, `node_modules/`, `reports/`, `target/`: _result_

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
THRESHOLDS 

    http_req_duration
    ✓ 'p(95)<1000' p(95)=191.19ms

    http_req_failed
    ✓ 'rate<0.01' rate=0.00%


  █ TOTAL RESULTS 

    checks_total.......: 440     14.434059/s
    checks_succeeded...: 100.00% 440 out of 440
    checks_failed......: 0.00%   0 out of 440

    ✓ status is 200
    ✓ greeting is correct

    HTTP
    http_req_duration..............: avg=177.34ms min=167.05ms med=176.12ms max=202.32ms p(90)=185.09ms p(95)=191.19ms
      { expected_response:true }...: avg=177.34ms min=167.05ms med=176.12ms max=202.32ms p(90)=185.09ms p(95)=191.19ms
    http_req_failed................: 0.00% 0 out of 220
    http_reqs......................: 220   7.217029/s

    EXECUTION
    iteration_duration.............: avg=688.69ms min=667.33ms med=677.43ms max=1.36s    p(90)=686.63ms p(95)=694.85ms
    iterations.....................: 220   7.217029/s
    vus............................: 5     min=5        max=5
    vus_max........................: 5     min=5        max=5

    NETWORK
    data_received..................: 86 kB 2.8 kB/s
    data_sent......................: 25 kB 832 B/s




running (0m30.5s), 0/5 VUs, 220 complete and 0 interrupted iterations
default ✓ [ 100% ] 5 VUs  30s