# Interview readiness log

A living record of what I built, why, and how I'll explain it in interviews.
Update it at the end of every milestone and after every incident drill.

**How to use it**

- *Key points* are prompts, not scripts. Write **My answer** in my own words after I've built that part.
- Practise each answer aloud in under 2 minutes. Mark confidence: 🔴 can't explain · 🟡 rough · 🟢 confident.
- Before an interview, reread sections 1, 2 and 5 and every 🟡 or 🔴 row.
- In Claude Code, say "quiz me on week N" to rehearse.

---

## 1. Pitch

**30-second version** (draft, refine after Week 6)

> I built Northwind Platform, an internal developer platform on AWS for a fictional 35-engineer company.
> It's multi-account and fully Terraform-managed, runs on EKS with Argo CD GitOps, and lets a new team
> onboard with a single pull request. Pipelines use OIDC with no stored keys, every service gets SLO-based
> alerting into Slack, and I validated it with five incident drills and written postmortems.

**2-minute version** — structure: problem → platform as product → architecture (draw it) → one incident story → what I'd do next.

My 2-minute version:

-

---

## 2. Design decisions and trade-offs

The questions interviewers ask most. Full detail in the design doc and `docs/adr/`.

| Decision | Likely question | Key points | Confidence |
| --- | --- | --- | --- |
| Monorepo | "Why one repo? Wouldn't you split it?" | Portfolio clarity, atomic changes for a solo builder. In production: separate GitOps repo for separation of duties and to avoid noisy syncs; path filters in CI. | 🔴 |
| EKS over ECS | "Isn't EKS overkill for 5 teams?" | Fair challenge. ECS Fargate is cheaper and simpler. Chose EKS for portability, GitOps ecosystem, Karpenter, multi-tenancy patterns, and because the market asks for it. Would recommend ECS to a small company with no K8s skills. | 🔴 |
| Multi-account | "Why four accounts for a prototype?" | Blast radius, separate billing, SCP guardrails, mirrors AWS landing-zone practice. Accounts cost nothing. | 🔴 |
| OIDC, no keys | "How does CI authenticate to AWS?" | GitHub OIDC token → `AssumeRoleWithWebIdentity`, trust policy scoped to repo + branch/environment, short-lived credentials, nothing to rotate or leak. | 🔴 |
| Pod Identity | "How do pods get AWS permissions?" | EKS Pod Identity agent, one IAM role per service, association by namespace + service account. Simpler than IRSA (no OIDC provider per cluster). | 🔴 |
| Shared cluster + namespaces | "How do you isolate tenants?" | Namespace per team, RBAC, ResourceQuota/LimitRange, default-deny NetworkPolicy, Kyverno policies, separate IAM roles. Trade-off: noisy neighbour risk vs cluster-per-team cost. | 🔴 |
| Single NAT in dev | "What happens if that AZ fails?" | Dev loses egress; accepted to save cost. Prod has one NAT per AZ. Documented in an ADR. | 🔴 |
| Slack, not PagerDuty | "How would on-call work for real?" | Slack proves the alert path. Real on-call needs paging, escalation, acknowledgement and rotations (PagerDuty/Opsgenie). | 🔴 |
| Python, not Go | "Why not Go for tooling?" | Python matches the team and ads, boto3 is mature. Go is better for K8s operators and single-binary CLIs; a stretch goal. | 🔴 |
| Tear-down per session | "Isn't that unrealistic?" | It's a cost decision for a prototype, and it proves the platform is fully reproducible from code, which is itself a DR test. | 🔴 |

---

## 3. Question bank by milestone

Fill **My answer** after finishing each week.

### Week 1 — Foundation (Organization, SCPs, state, OIDC, Terraform CI)

| Question | Key points | My answer | Confidence |
| --- | --- | --- | --- |
| Walk me through your AWS account structure. | OUs, 4 accounts, why each exists, SCPs at OU level. | | 🔴 |
| What does an SCP do that IAM doesn't? | Guardrail on max permissions for an account; can't grant, only limit; applies even to admins (not management account). | | 🔴 |
| How is Terraform state stored and locked? | S3 bucket, versioning, encryption, `use_lockfile`; why not local state; how to recover. | | 🔴 |
| How do you stop someone applying to prod by accident? | PR plan review, GitHub Environment approval, separate roles per env, SCPs. | | 🔴 |

### Week 2 — Network and cluster

| Question | Key points | My answer | Confidence |
| --- | --- | --- | --- |
| Describe your VPC design. | 3 AZs, public/private subnets, NAT, VPC endpoints, why nodes are private. | | 🔴 |
| Why Karpenter over Cluster Autoscaler? | Provisions right-sized nodes directly, faster, spot handling, consolidation. | | 🔴 |
| How does traffic reach a pod? | Route 53 → ALB (LB controller, Ingress) → target group in IP mode → pod. | | 🔴 |
| How long does `make up` take, and what's slowest? | Measure it. EKS control plane is the bulk. | | 🔴 |

### Week 3 — GitOps and self-service

| Question | Key points | My answer | Confidence |
| --- | --- | --- | --- |
| What is GitOps and why use it? | Git as desired state, pull-based reconcile, drift correction, audit trail, easy rollback. | | 🔴 |
| What happens when a team adds `teams/x.yaml`? | Walk through the whole chain: PR → plan → apply → tenant resources → Argo AppProject. | | 🔴 |
| What is "platform as a product"? | Users are developers; golden paths; self-service; measure adoption and lead time. | | 🔴 |

### Week 4 — Apps, pipeline, security

| Question | Key points | My answer | Confidence |
| --- | --- | --- | --- |
| Walk me through your CI/CD pipeline. | Test → build → Trivy → ECR → tag bump → Argo sync → PR promotion. | | 🔴 |
| How do secrets reach the app? | Secrets Manager → External Secrets Operator → K8s Secret → env/volume; KMS. | | 🔴 |
| What policies does Kyverno enforce, and why? | Non-privileged, limits required, ECR-only images; prevents unsafe workloads at admission. | | 🔴 |
| How do you roll back a bad release? | `git revert` on the GitOps commit; Argo syncs back. | | 🔴 |

### Week 5 — Observability

| Question | Key points | My answer | Confidence |
| --- | --- | --- | --- |
| What's the difference between an SLI, SLO and SLA? | Measure, target, contract. | | 🔴 |
| Why burn-rate alerts instead of threshold alerts? | Alert on error-budget spend speed; fewer false pages; multi-window. | | 🔴 |
| Metrics vs logs vs traces — when do you use each? | Detect with metrics, explain with traces, detail with logs. | | 🔴 |

### Week 6 — Drills, cost, polish

| Question | Key points | My answer | Confidence |
| --- | --- | --- | --- |
| Tell me about an incident you handled. | Use a STAR story from section 4. | | 🔴 |
| How do you control cloud cost? | Tags, budgets, Infracost, OpenCost per team, spot, teardown. Give real numbers from the bill. | | 🔴 |
| What would you do differently / next? | Honest gaps: multi-region, policy-as-code for Terraform (OPA), Backstage portal, Argo Rollouts canary. | | 🔴 |

---

## 4. STAR stories from incident drills

Write one per drill straight after running it, while the details are fresh. Link evidence from `docs/evidence/`.

### Drill 1 — Latency spike on orders-api

- **Situation:**
- **Task:**
- **Action:** (alert received → dashboard → runbook → mitigation)
- **Result:** (time to detect, time to recover, SLO budget spent)
- **What I improved afterwards:**
- **Evidence:**

### Drill 2 — Bad deploy (crash loop)

- **Situation:**
- **Task:**
- **Action:**
- **Result:**
- **What I improved afterwards:**
- **Evidence:**

### Drill 3 — Node loss

- **Situation:**
- **Task:**
- **Action:**
- **Result:**
- **What I improved afterwards:**
- **Evidence:**

### Drill 4 — Broken IAM permission

- **Situation:**
- **Task:**
- **Action:**
- **Result:**
- **What I improved afterwards:**
- **Evidence:**

### Drill 5 — SQS backlog

- **Situation:**
- **Task:**
- **Action:**
- **Result:**
- **What I improved afterwards:**
- **Evidence:**

---

## 5. Real numbers to quote

Interviewers trust measured numbers. Fill from real runs.

| Metric | Value | Source |
| --- | --- | --- |
| `make up` duration (dev) | | terminal timing |
| `make down` duration (dev) | | terminal timing |
| Cost per session (8h) | | AWS Cost Explorer |
| Monthly idle cost | | AWS Cost Explorer |
| Time to onboard a new team (PR open → namespace ready) | | PR timestamps |
| Commit → running in dev | | Actions + Argo CD history |
| Drill 1 time to detect | | Slack alert timestamp |
| Drill 2 time to recover | | Argo CD history |

---

## 6. CV bullets (draft, update with real numbers)

- Designed and built a multi-account AWS internal developer platform (Terraform, EKS, Argo CD) where onboarding a new team takes a single pull request.
- Implemented keyless CI/CD with GitHub Actions OIDC, Trivy/Checkov scanning and GitOps promotion from dev to prod.
- Introduced SLO burn-rate alerting (Prometheus, Grafana, Loki, Tempo) and validated it with five incident drills and blameless postmortems.
- Kept running cost to about £X per session through spot capacity, tagging, budgets and fully reproducible teardown.

---

## 7. Gaps I can name honestly

Saying these confidently is a strength, not a weakness.

- Single region; no cross-region DR.
- No real users or production traffic; load comes from synthetic tests.
- No paging/on-call rotation.
- Terraform guardrails via Checkov only; no OPA/Sentinel policy-as-code yet.
