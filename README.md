# Northwind Platform

**An AWS internal developer platform where a new product team onboards with one pull request.**
Multi-account AWS, Terraform, EKS, Argo CD GitOps, keyless CI/CD and SLO-based alerting,
validated with five incident drills.

> 🚧 **Status:** `v0.1-foundation` done: AWS Organization, SCPs, and keyless Terraform CI.
> Week 2 (VPC + EKS) is next. See the [roadmap](#roadmap) for progress.

![Architecture](docs/diagrams/architecture.png)

<sub>Target architecture. Built so far: the AWS Organization, the bootstrap (state and OIDC roles)
and the delivery pipeline. Generated from code:
[`docs/diagrams/architecture.py`](docs/diagrams/architecture.py) · `make diagram`</sub>

---

## The scenario

Northwind Logistics (fictional) has about 80 staff and 35 engineers in 5 product teams.
Teams used to file tickets for infrastructure. This platform replaces those tickets with
self-service golden paths, so teams ship safely without waiting on a platform engineer.

**Platform promises to its users**

- **Onboard in one PR** — add `teams/<team>.yaml` and get a namespace, RBAC, quotas, network policy, ECR repo, IAM role and Argo CD project.
- **Ship safely** — every commit is tested, scanned, and deployed by GitOps; promotion to prod is a reviewed PR.
- **See everything** — metrics, logs, traces, a dashboard and an SLO for every service by default.
- **Know the cost** — per-team cost visibility and a monthly budget alarm.

---

## What this demonstrates

✅ built, with a link to the code or proof · 🗓 planned, with the week it lands.

| Skill | Where to look | Status |
| --- | --- | --- |
| AWS core: VPC, IAM, EKS, DynamoDB, SQS, KMS, Route 53 | IAM: [`terraform/bootstrap/`](terraform/bootstrap/), [`terraform/org/`](terraform/org/) · the rest: `terraform/modules/`, `terraform/envs/` | ✅ IAM · 🗓 Weeks 2–4 |
| Infrastructure as Code (Terraform) | S3 remote state with native locking, pinned providers with lockfile hashes, imported console resources · modules and env split | ✅ state, pins, imports · 🗓 modules (Week 2) |
| Multi-account governance | [`terraform/org/`](terraform/org/) — Organizations, deny-list SCPs, region lock, org CloudTrail, budget ([region deny](docs/evidence/2026-10-29-scp-region-deny.png), [trail event](docs/evidence/2026-10-29-cloudtrail-scp-deny-event.png)) | ✅ |
| Kubernetes on EKS | Karpenter (spot), LB controller, Pod Identity | 🗓 Week 2 |
| CI/CD (GitHub Actions) | [`ci.yml`](.github/workflows/ci.yml) — OIDC with no stored keys, plan on PR, approval-gated apply on merge ([OIDC apply log](docs/evidence/2026-11-16-apply-oidc-role.png), [PR plan](docs/evidence/2026-11-10-pr-plan-infracost.png), [push to `main` rejected](docs/evidence/2026-11-09-protect-main-push-rejected.png)) | ✅ |
| GitOps (Argo CD) | `gitops/` — app-of-apps, promotion by PR, rollback by `git revert` | 🗓 Week 3 |
| Self-service platform | `teams/` + `terraform/modules/tenant/` | 🗓 Week 3 |
| Observability and SLOs | Prometheus, Grafana, Loki, Tempo, OpenTelemetry; burn-rate alerts to Slack | 🗓 Week 5 |
| Security by design | SCPs, keyless CI, Checkov as a blocking check ([finding on a PR](docs/evidence/2026-11-11-pr-checkov-finding.png)), Trivy, gitleaks, SHA-pinned actions · Kyverno, External Secrets | ✅ CI and guardrails · 🗓 Kyverno, ESO (Week 4) |
| FinOps | [£20 budget](terraform/org/budget.tf), mandatory tags checked on PRs ([ADR 0037](docs/adr/0037-mandatory-tags-on-prs.md), [passing check](docs/evidence/2026-11-16-infracost-tags-pass.png), Infracost trial), Infracost cost diff on PRs · spot, `make down` teardown verifier, OpenCost per team | ✅ budget, tags, cost diff · 🗓 Weeks 2 and 6 |
| Python | `apps/` (FastAPI) and `tools/` with pytest | 🗓 Weeks 2–4 |
| Operations | [ADRs](docs/adr/) · [runbooks](docs/runbooks/), [postmortems](docs/postmortems/) | ✅ ADRs · 🗓 Weeks 5–6 |

---

## Demo and evidence

<!-- Replace with real captures from docs/evidence/ as milestones land. -->

| | |
| --- | --- |
| 🎬 **Demo video** (2–3 min): `make up` → deploy → drill → alert | _coming in Week 6_ |
| Grafana SLO dashboard during drill 1 | _Week 5_ |
| Slack burn-rate alert with runbook link | _Week 5_ |
| Argo CD application tree | _Week 3_ |
| PR with Terraform plan and Infracost comments | [screenshot](docs/evidence/2026-11-10-pr-plan-infracost.png) |
| Checkov finding blocking a PR | [screenshot](docs/evidence/2026-11-11-pr-checkov-finding.png) |
| Apply job running on OIDC credentials, no stored keys | [screenshot](docs/evidence/2026-11-16-apply-oidc-role.png) |
| Region-lock SCP denying a create outside eu-west-2 | [screenshot](docs/evidence/2026-10-29-scp-region-deny.png) |

All screenshots live in [`docs/evidence/`](docs/evidence/).

---

## Architecture at a glance

| Layer | Built with | Lifecycle |
| --- | --- | --- |
| AWS Organization — `management`, `shared-services`, `workloads-dev`, `workloads-prod` | Terraform | Persistent |
| Shared services — ECR, Terraform state, Route 53 subdomain | Terraform | Persistent |
| Network — VPC, 3 AZs, NAT, VPC endpoints | Terraform | Per session |
| EKS cluster — Karpenter, LB controller, Pod Identity | Terraform | Per session |
| Platform services — monitoring, logging, tracing, policy, secrets, cost | Argo CD | Per session |
| Tenants and workloads — `orders-api`, `payments-worker` | Argo CD | Per session |

Design detail and trade-offs: [`docs/architecture.md`](docs/architecture.md) and [`docs/adr/`](docs/adr/).

---

## Quick start

Prerequisites: an AWS Organization management account, a domain with a subdomain you can delegate,
a GitHub repo, and a Slack webhook. All tooling is pinned in the [dev container](.devcontainer/).

AWS access uses IAM Identity Center, with no long-lived keys. Add these profiles to `~/.aws/config`.
They share one `sso-session`, so a single login covers every account
([ADR 0040](docs/adr/0040-local-sso-profiles-for-member-accounts.md)):

```ini
[sso-session np-sso]
sso_start_url           = https://<your-portal>.awsapps.com/start
sso_region              = eu-west-2
sso_registration_scopes = sso:account:access

# Terraform state for every stack, plus the bootstrap and org resources
[profile nw-management]
sso_session    = np-sso
sso_account_id = <management-account-id>
sso_role_name  = AdministratorAccess
region         = eu-west-2

# Resources in shared-services (terraform/envs/shared)
[profile nw-shared]
sso_session    = np-sso
sso_account_id = <shared-services-account-id>
sso_role_name  = NwAdmin
region         = eu-west-2

# Resources in workloads-dev (terraform/envs/dev)
[profile nw-dev]
sso_session    = np-sso
sso_account_id = <workloads-dev-account-id>
sso_role_name  = NwAdmin
region         = eu-west-2
```

```bash
# 0. Open in VS Code → "Reopen in Container", then sign in once for every account
aws sso login --sso-session np-sso

# 1. One-off foundation (state bucket, OIDC roles, organization)
make bootstrap

# 2. Start a working session (about 20–25 min)
make up ENV=dev

# 3. Run an incident drill and watch Grafana + Slack
make drill-1

# 4. End the session — destroys network and cluster, verifies nothing is left running
make down ENV=dev
```

---

## Cost

| State | Approximate cost |
| --- | --- |
| Session running (EKS, 2–3 spot nodes, NAT, ALB) | $0.35–0.50 per hour (about £2.50–3.50 per 8-hour session) |
| Torn down (S3 state, ECR images, Route 53 zone, Secrets) | about £1–2 per month |
| Budget alarm | £20 per month |

Estimates; measured figures will replace them after Week 2.

---

## Roadmap

| Milestone | Scope | Status |
| --- | --- | --- |
| `v0.1-foundation` | Organization, SCPs, state, OIDC, Terraform CI | ✅ |
| `v0.2-cluster` | VPC, EKS, Karpenter, DNS, `make up/down` | ⬜ |
| `v0.3-gitops` | Argo CD, platform services, tenant self-service | ⬜ |
| `v0.4-delivery` | Apps, app pipeline, Kyverno, secrets, promotion | ⬜ |
| `v0.5-observability` | Dashboards, SLOs, burn-rate alerts, runbooks | ⬜ |
| `v0.6-drills` | Five incident drills, postmortems, OpenCost, demo | ⬜ |

---

## Repository layout

```
terraform/   bootstrap/  org/  modules/{vpc,eks,tenant,dns}/  envs/{shared,dev,prod}/
gitops/      bootstrap/  platform/  tenants/  apps/
teams/       self-service entry point, one YAML per team
apps/        orders-api/  payments-worker/
tools/       Python CLIs: tag checker, cost report, teardown verifier
docs/        architecture.md  adr/  runbooks/  postmortems/  evidence/  diagrams/  interview/
.devcontainer/  pinned toolchain for VS Code / Codespaces
```

---

## Known limitations

Single region, synthetic traffic only, Slack instead of paging, and no policy-as-code gate on
Terraform beyond Checkov. Each is recorded as a conscious trade-off in [`docs/adr/`](docs/adr/).

Open foundation gaps, each tracked:

- The CI apply role has `AdministratorAccess` until it is scoped down
  ([#3](https://github.com/YanzhengL/northwind-platform/issues/3)).
- Terraform state and the CI roles live in the management account until they move to
  `shared-services` ([#4](https://github.com/YanzhengL/northwind-platform/issues/4), [ADR 0013](docs/adr/0013-bootstrap-in-management-account.md)).
- Mandatory tags are enforced by a custom Checkov policy that blocks the merge; the
  Infracost tag check was a trial and is now optional ([ADR 0037](docs/adr/0037-mandatory-tags-on-prs.md)).

## About

Built by **<Your Name>** ([LinkedIn](https://www.linkedin.com/in/<your-profile>)) as a hands-on portfolio project for AWS Platform Engineer roles.
AI pair-programming (Claude Code) was used for review, explanation and boilerplate; design and
core infrastructure code are my own. Conventions are in [`CLAUDE.md`](CLAUDE.md).
