# Deployment configuration

## Environments

| Environment | Apigee org (GCP project) | Hostname | Deployed by |
|---|---|---|---|
| `dev` | `apigee-nonprod-511322` | `35.201.86.122.nip.io` | `main-deploy-nonprod` (every merge to `main`) |
| `staging` | `apigee-nonprod-511322` | `staging.35.201.86.122.nip.io` | `main-deploy-nonprod`, after dev tests pass |
| `prod` | `apigee-prod-511508` | `136.68.4.183.nip.io` | `release-prod` (manual, approval required) |

The proxy bundle is the same in every environment; only where it runs changes.
Hostname setup and troubleshooting: see the environments guide (Apigee Non-Prod Environments Guide).

## Pipelines

All pipelines run in Cloud Build, project `ci-cd-511313`, region `europe-west1`.

| Trigger | Event | Config file | Service account |
|---|---|---|---|
| `pr-validate` | Pull request to `main` | `cloudbuild-pr.yaml` | `cb-validate` |
| `main-deploy-nonprod` | Push to `main` | `cloudbuild-main.yaml` | `cb-deploy-nonprod` |
| `release-prod` | Manual, approval required | `cloudbuild-prod.yaml` | `cb-deploy-prod` |

### How a revision moves

1. **dev:** Maven (`clean install -Pdev`) imports the bundle as a new revision *N* and deploys it.
   Before that, the pipeline writes `hello-v1 | commit <id> | build <id>` into the bundle description.
2. **staging:** `scripts/deploy-revision.sh` deploys exactly revision *N*, the revision the dev tests
   ran against. Nothing is imported or rebuilt.
3. **prod:** `scripts/copy-revision.sh` exports the revision that is READY in staging from the
   non-prod org and imports that same zip into the prod org; `deploy-revision.sh` deploys it.

After each deployment, `scripts/wait-for-deployment.sh` waits until Apigee reports the revision
`READY`, then the 21 Newman assertions run against that environment.

Why promotion uses the Apigee API and not the Maven `promote` goal: `promote` takes whatever is
deployed in the source environment at that moment. The script deploys the exact revision number
that passed the tests, so a newer, untested revision can never slip through.

## Identities and roles

No service account keys exist. Builds use the identity of their trigger's service account.

| Identity | Used by | Roles |
|---|---|---|
| `cb-validate@ci-cd-511313` | `pr-validate` | `logging.logWriter` on `ci-cd-511313` only |
| `cb-deploy-nonprod@ci-cd-511313` | `main-deploy-nonprod` | `apigee.apiAdminV2`, `apigee.environmentAdmin` on `apigee-nonprod-511322`; `logging.logWriter` |
| `cb-deploy-prod@ci-cd-511313` | `release-prod` | `apigee.apiAdminV2`, `apigee.environmentAdmin` on `apigee-prod-511508`; `apigee.readOnlyAdmin` on `apigee-nonprod-511322`; `logging.logWriter` |
| `gcp.apigee.poc@gmail.com` | Prod approver; manual operations | `cloudbuild.builds.approver` on `ci-cd-511313`; project Owner |

## Releasing to prod

1. Make sure the latest `main-deploy-nonprod` build is green (staging holds the tested revision).
2. Cloud Build → Triggers → `release-prod` → **Run** (branch `main`).
3. Cloud Build → History → the build shows **Awaiting approval** → review → **Approve**.
4. Check the `summary` step: staging revision, prod revision, and the commit stamp.

## Manual commands (fallback and local use)

Run from the repo root (PowerShell). Quote `-D` arguments.

```powershell
# Package only (no call to Apigee)
npm run package

# Manual deploy to dev, as on Day 3
mvn -f src/main/apigee/apiproxies/hello-v1/pom.xml clean install -Pdev "-Dbearer=$(gcloud auth print-access-token)"

# Tests against any environment
npm run test:dev
npm run test:staging
npm run test:prod
```

Manual deploys bypass the pipeline's gates and traceability. Use them only for troubleshooting.

## Environment resources the proxy needs

| Resource | Needed? | Notes |
|---|---|---|
| Target servers | No | No-target proxy |
| KVMs | No | No configuration values |
| Secrets | No | Nothing to store in Secret Manager |
| Environment-specific config (`config.json`) | No | Bundle is identical in every environment |
| Environment group hostname | Yes | One per environment (see table above) |

If a target server, KVM or secret is added later, add it to this table, keep the value out of Git
(Secret Manager), and decide whether it is created manually or by automation.
