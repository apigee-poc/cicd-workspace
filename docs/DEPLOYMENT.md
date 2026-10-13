# Deployment configuration

## Environments

| Maven profile | Apigee org (GCP project) | Apigee env | Used on |
|---|---|---|---|
| `dev` | `apigee-nonprod-511322` | `dev` | Day 3: first deploy + post-deploy tests |
| `staging` | `apigee-nonprod-511322` | `staging` | Day 4: promotion of the tested revision |
| `prod` | `apigee-prod-511508` | `prod` | Out of scope for the demo |

Profiles live in `deploy/shared-pom.xml`. The proxy bundle is the same for every
environment; only the profile changes.

## Commands

Run from the repo root.

```powershell
# Package only (no call to Apigee)
mvn -f src/main/apigee/apiproxies/hello-v1/pom.xml clean package -Pdev

# Deploy (Day 3). Quote -D arguments in PowerShell.
mvn -f src/main/apigee/apiproxies/hello-v1/pom.xml clean install -Pdev "-Dbearer=$(gcloud auth print-access-token)"

# Promote the revision that is deployed in dev to staging (Day 4)
mvn -f src/main/apigee/apiproxies/hello-v1/pom.xml apigee-enterprise:promote -Pstaging "-Dbearer=$(gcloud auth print-access-token)" "-Dapigee.promote.sourceEnv=dev"
```

## Environment resources the proxy needs

| Resource | Needed? | Notes |
|---|---|---|
| Target servers | No | No-target proxy |
| KVMs | No | No configuration values |
| Secrets | No | Nothing to store in Secret Manager |
| Environment-specific config (`config.json`) | No | Bundle is identical in every environment |
| Environment group hostname | Yes | One per env (`dev`, `staging`), set up on Day 3 |

If a target server, KVM or secret is added later, add it to this table, keep the
value out of Git (Secret Manager or CI secrets), and decide whether it is created
manually or by automation.

## Credentials

- No credential is stored in this repo.
- Locally: `gcloud auth print-access-token` (your own Google account).
- In CI (Day 3–4): a service account in `ci-cd-511313` via Workload Identity Federation.

| Identity | Used for | Roles on apigee-nonprod-511322 |
|---|---|---|
| Your Google account | Manual deploys (Day 3) | Project Owner (existing) |
| CI service account in ci-cd-511313 | GitHub Actions deploys (Day 3–4) | roles/apigee.apiAdminV2, roles/apigee.environmentAdmin |