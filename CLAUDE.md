# CLAUDE.md — Northwind Platform

Instructions for Claude Code working in this repository. Read this fully before any change.

## 1. What this repository is

A portfolio prototype of an **AWS internal developer platform** for a fictional company, Northwind Logistics: about 80 staff, 35 engineers in 5 product teams. The repo owner is the platform team. The platform is the product; product teams are its users.

The repo serves three goals, in this order of priority:

1. **Platform** — a working, secure, observable AWS platform built entirely as code.
2. **CV and job applications** — evidence that the owner is a credible mid-level AWS Platform Engineer in the UK market (see section 4).
3. **Interview readiness** — the owner must be able to explain and defend every line
   (see section 5).

If a request conflicts with goal 3 (for example "just generate the whole module"), help the owner understand the code rather than writing it silently.

## 2. Platform requirements

| Area | Requirement |
| --- | --- |
| Region | `eu-west-2` only. Enforced by SCP. Never create resources elsewhere (except global services such as IAM, Route 53, Organizations). |
| Accounts | AWS Organizations: `management`, `shared-services`, `workloads-dev`, `workloads-prod`. |
| IaC | Terraform only. Remote state in S3 with native lockfile (`use_lockfile = true`). No ClickOps; anything created by hand must be imported or documented in `docs/adr/`. |
| Kubernetes | EKS, Karpenter (spot in dev), AWS Load Balancer Controller, EKS Pod Identity (not IRSA). |
| Delivery | GitHub Actions authenticating to AWS via OIDC. **No long-lived AWS keys anywhere** — not in GitHub, not in code, not on the laptop (use `aws sso login`). |
| GitOps | Argo CD app-of-apps syncs `gitops/`. Nobody runs `kubectl apply` for platform or app resources. Rollback = `git revert`. |
| Self-service | A team onboards by adding `teams/<team>.yaml`. The `tenant` module creates namespace, RBAC, ResourceQuota, default-deny NetworkPolicy, ECR repo, IAM role, Argo CD AppProject. |
| Observability | kube-prometheus-stack, Loki, Tempo, OpenTelemetry. Every service has metrics, logs, traces, a dashboard and an SLO. Every alert links to a runbook. Alerts go to Slack. |
| Security | SCPs, least-privilege IAM, Kyverno policies, External Secrets Operator + Secrets Manager, KMS encryption, Checkov and Trivy in CI, gitleaks pre-commit. |
| Cost | Mandatory tags `team`, `env`, `service`, `owner`. £20/month budget alarm. Infracost on Terraform PRs. Network and cluster layers are destroyed after every session with `make down`. |
| Language | Python 3.12 for apps (FastAPI) and tools. Bash only for thin wrappers. |

### Cost guardrails (always check)

- Before suggesting any new AWS resource, state its approximate hourly or monthly cost.
- Never add: NAT gateways beyond the design, RDS, OpenSearch, EKS add-ons with per-hour fees,
  GuardDuty beyond the trial, or anything always-on in `workloads-*` without asking.
- Anything in `terraform/envs/dev` or `terraform/envs/prod` must be destroyable by `make down`.

## 3. Repository conventions

```
terraform/   bootstrap/ org/ modules/{vpc,eks,tenant,dns}/ envs/{shared,dev,prod}/
gitops/      bootstrap/ platform/ tenants/ apps/<app>/{base,dev,prod}/
teams/       one YAML per team (self-service entry point)
apps/        orders-api/ payments-worker/
tools/       Python CLIs with pytest tests
docs/        architecture.md adr/ runbooks/ postmortems/ evidence/ diagrams/ interview/
```

**Terraform**
- One module = one purpose; inputs and outputs documented in `variables.tf` / `outputs.tf` with descriptions and types.
- Pin provider and module versions. `terraform fmt` and `tflint` must pass.
- Resource names: `nw-<env>-<component>` (e.g. `nw-dev-eks`). Tags via `default_tags` in the provider.
- No hard-coded account IDs or ARNs: use data sources or variables.

**Kubernetes / GitOps**
- Kustomize overlays per environment; Helm charts pinned to a version.
- Every workload: resource requests and limits, liveness and readiness probes, non-root user, read-only root filesystem where possible.

**Python**
- Ruff for lint and format, type hints, pytest. Each tool has a `--help` and a README line.
- Apps expose `/healthz`, `/metrics`, and chaos switches under `/chaos/*` (disabled in prod unless a drill flag is set).

**Git**
- Branch from `main`, open a PR, never push to `main` directly.
- Conventional commits: `feat(eks): add karpenter nodepool`, `fix(ci): pin terraform 1.9`, `docs(adr): 0004 single nat in dev`.
- One logical change per PR. PR description: what, why, how tested, cost impact.

## 4. CV and job-application requirements

The repo will be linked from the owner's CV and job applications. Optimise for a reviewer who spends **5 minutes**.

- `README.md` must always show: one-line pitch, architecture diagram, "what this demonstrates" table, demo video/screenshots, quick start, cost, links to ADRs/runbooks/postmortems.
- `docs/diagrams/architecture.py` is the single source of the diagrams. When a component is added or removed, update it **in the same PR** and run `make diagram`.
  - `architecture.png` — detailed, for README and interviews.
  - `architecture-cv.png` — about 8 boxes, for the CV. Keep it simple.
- `docs/evidence/` holds proof captured from real runs: Grafana SLO panels, Slack alerts, Argo CD trees, PR plan comments, Infracost comments. Name files `YYYY-MM-DD-<what>.png` and reference them from the README or postmortems.
- Each GitHub milestone ends with a tag (`v0.1-foundation` … `v0.6-drills`) and short release notes.
- Never commit anything that weakens the story: secrets, account IDs in screenshots (blur them), `TODO: fix later` without an issue link, disabled security checks.

## 5. Interview-readiness rules (how Claude should work here)

The owner must be able to explain every design choice on a whiteboard.

1. **Explain before writing.** For any non-trivial change, first give a short plan: what, why, alternatives considered, trade-off. Then write code only if asked or agreed.
2. **The owner writes the core.** Terraform modules, the tenant module, pipeline YAML, SLO and alert rules are written by the owner. Claude reviews, explains, debugs and suggests. Claude may write boilerplate freely: Dockerfiles, test scaffolding, Grafana dashboard JSON, Makefile targets, README formatting.
3. **No unexplained magic.** Every generated block gets a one-line comment explaining *why*, not *what*.
4. **Record decisions.** When a meaningful choice is made, draft an ADR in `docs/adr/NNNN-title.md` (context, decision, alternatives, consequences).
5. **Update the interview log.** After each milestone or incident drill, add entries to `docs/interview/interview-readiness.md`: likely questions, the owner's answer in their words, and a STAR story if relevant. Prompt the owner to do this if they forget.
6. **Quiz on request.** When the owner says "quiz me", ask 5 interview questions about the most recent work and give feedback on the answers.

## 6. Commands

```
make bootstrap     # one-off: state bucket + OIDC roles (run with management credentials)
make up            # create dev network + cluster, bootstrap Argo CD
make down          # destroy dev network + cluster; run teardown verifier
make plan ENV=dev  # terraform plan for an environment
make drill-1       # incident drill 1 (latency), see docs/runbooks/
make diagram       # regenerate docs/diagrams/*.png
make lint          # pre-commit run --all-files
make test          # pytest for apps and tools
```

## 7. Safety

- Never run `terraform apply`, `terraform destroy`, `kubectl delete`, or any AWS CLI command that creates, changes or deletes resources without the owner's explicit go-ahead in this session.
- Never print or commit secrets, tokens, webhook URLs or account IDs.
- If unsure whether something costs money or is reversible, ask first.
