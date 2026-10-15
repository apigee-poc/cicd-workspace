# Demo checklist, retrospective and next steps

## Demo flow (about 20 minutes)

| # | Show | Where | Point to make |
|---|---|---|---|
| 1 | The proxy and its tests | VS Code, `tests/hello-v1.postman_collection.json` | 7 requests, 21 assertions, one test suite for every environment |
| 2 | Local development | Cloud Code emulator, `npm run test:local` | Develop and test without any cloud access |
| 3 | Lint gate failing | Day 3 red-run screenshot (or open a PR that reintroduces the long condition) | A warning blocks the merge |
| 4 | A pull request | GitHub PR, `pr-validate (ci-cd-511313)` check | Required check; runs as an account with no Apigee access |
| 5 | Merge → automatic release | Cloud Build → History → `main-deploy-nonprod` | dev deploy, dev tests, same revision to staging, staging tests |
| 6 | Traceability | Revision description in dev, staging, prod | `hello-v1 \| commit <id> \| build <id>` matches the commit on `main` |
| 7 | Prod release | Run `release-prod`, approve | Approval gate; prod gets the exact bundle from staging |
| 8 | Prod smoke test | `release-prod` log, `npm run test:prod` | 21/21 in prod |
| 9 | Security review | `docs/CONFIG_REVIEW.md` | No keys, no secrets in history or logs, least privilege |
| 10 | Performance baseline | `docs/CONFIG_REVIEW.md` section 5 | p95 191 ms on dev, with its limits |

Have ready: screenshots of the Day 3 red run, the latest green builds, and the prod `summary` step.

## What is complete

- Local development with the emulator; a no-target proxy with input validation.
- Quality gates: apigeelint (warnings fail), 21 functional assertions, pinned tool versions.
- Cloud Build pipelines: PR validation, automatic dev → staging release, approved prod release.
- Promotion without rebuilding; commit stamp in every revision; full traceability.
- Least-privilege service accounts; no keys; secret scan clean.

## What is optional or partial

- Performance: one small baseline on dev; no load or soak test.
- Test reports: JUnit files are produced in builds but not stored after the build.

## Next steps before production (backlog)

| # | Item | Why |
|---|---|---|
| 1 | Paid Apigee orgs | Eval orgs are deleted after 60 days |
| 2 | Company domain and DNS instead of nip.io | Real hostnames, managed certificates on your own domain |
| 3 | Infrastructure as code (Terraform) for orgs, env groups, certificates, service accounts, triggers | Everything marked ❌ in `CONFIG_REVIEW.md` section 4 is manual today |
| 4 | Automated rollback | If prod smoke tests fail, redeploy the previous prod revision |
| 5 | Monitoring and alerting | Apigee analytics, Cloud Monitoring alerts on errors and latency |
| 6 | Keep test reports and build evidence | Store JUnit and lint reports in Cloud Storage per build |
| 7 | Independent release artifact store | Survives loss or cleanup of the non-prod org (disaster recovery, audit) |
| 8 | Authentication on the API | API keys or OAuth with API products and developer apps |
| 9 | Maven dependency caching in Cloud Build | Faster builds |
| 10 | One release at a time | Prevent two `main` builds deploying concurrently |
| 11 | Regular access reviews | Confirm approvers and service account roles stay minimal |
