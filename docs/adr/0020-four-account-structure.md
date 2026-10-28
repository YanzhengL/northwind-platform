# 0020. Four accounts in two OUs: management, shared-services, workloads-dev, workloads-prod

- **Status:** accepted
- **Date:** 2026-10-24

## Context
Northwind has about 35 engineers in 5 product teams, a dev and a prod environment, and a platform
team that runs shared tooling (Terraform state, CI roles, container images, DNS, logs).

In AWS, the account is the strongest isolation boundary. IAM policies can be mis-scoped, but a
mistake in one account cannot touch resources in another unless cross-account access is granted
explicitly. Accounts also give per-environment billing for free, and they are where SCPs attach.

Day 1 left everything in the management account (ADR 0013). AWS guidance is to keep that account
nearly empty, because SCPs do not apply to it and anything with admin there has organisation-wide
power.

## Decision
Use AWS Organizations with all features enabled, and four accounts:

| Account | OU | Holds |
| --- | --- | --- |
| `management` | root | Organizations, billing and budgets, IAM Identity Center. Temporarily: state bucket and CI roles (ADR 0013, #4). |
| `shared-services` | `Infrastructure` | Terraform state and CI roles after migration, ECR, Route 53 zones, shared tooling. |
| `workloads-dev` | `Workloads` | Dev VPC and EKS cluster. Destroyed after every session with `make down`. |
| `workloads-prod` | `Workloads` | Prod VPC and EKS cluster. Mostly empty until needed, to stay inside the £20 budget. |

Accounts are created by `terraform/org` with `aws_organizations_account`, using email
sub-addressing (`owner+nw-<account>@...`) and `prevent_destroy`. People reach them through
Identity Center permission sets (admin and read-only), never IAM users.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Four accounts in two OUs (`Infrastructure`, `Workloads`) (chosen) | Accounts isolate prod from dev and keep shared tooling out of management; OUs group accounts that share the same SCPs; small enough to run alone | Cross-account access needed for ECR pulls and CI; more Identity Center assignments |
| Separate `Prod` / `NonProd` OUs under `Workloads` | Different guardrails per environment (e.g. deny deleting the cluster or KMS keys only in prod) | No policy difference between dev and prod yet; adds a level to reason about. Revisit when a prod-only SCP is needed: moving an account between OUs is in place, not a rebuild |
| Single account, separated by tags and IAM | Simplest; no cross-account wiring | One IAM mistake reaches prod; no SCP boundary; billing split only by tags |
| Two accounts (management + one workload account) | Gets workloads out of management | Dev and prod share a blast radius and quotas |
| Full AWS Security Reference Architecture / Control Tower (log archive, audit, sandbox, per-team accounts) | Industry reference; separate log archive and security tooling | AWS Config rules and extra accounts cost money; heavy for a 5-team company and a portfolio budget; Control Tower is opinionated and harder to explain line by line |
| One account per team per environment | Strongest tenant isolation; per-team billing | 10+ accounts to run; the platform's tenant model is namespaces on a shared cluster, so this duplicates it |

## Consequences
- Dev can be broken or destroyed without risk to prod, and each environment's cost shows up per
  account in Cost Explorer.
- SCP guardrails (ADR 0021, 0022) attach to OUs, so a new account placed in `Workloads` inherits
  them automatically.
- Cross-account work is now required: ECR in `shared-services` needs a repository policy allowing
  pulls from the workload accounts, and CI needs a role per account (follow-up from ADR 0012).
- Closing an account is slow and limited (90-day post-closure period, closure quotas), so account
  names and emails must be checked in the plan before the first apply.
- The management account still holds the bootstrap stack until #4 is done.
- Cost: accounts and OUs are free. Only the resources inside them cost money.

## To confirm during implementation
- [ ] Where the organization CloudTrail log bucket lives (management now, or `shared-services`).
- [ ] Whether a separate `Security` OU / log-archive account is worth adding later.
- [ ] Final OU names, and whether `shared-services` holds Route 53 zones or management does.

## Interview angle
"Why four accounts?" - The account is AWS's hardest isolation boundary. I separated prod from dev so a
mistake in dev can't reach prod, and moved shared tooling out of management because SCPs don't apply
there. I stopped at four because a full landing zone with log-archive and audit accounts costs more and
adds accounts I'd have to run alone. I know what I'd add next: a log-archive account.
