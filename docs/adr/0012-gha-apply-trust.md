# 0012. Gate the apply role behind a protected GitHub Environment

- **Status:** accepted
- **Date:** 2026-10-16
- **Amended:** 2026-10-30 - environment renamed from `production` to `terraform-apply`. The gate
  guards every Terraform apply (today the management account, later dev too), not the
  `workloads-prod` account, so `production` was misleading. Per-account environments wait for
  per-account apply roles (#4).
- **Amended:** 2026-11-13 - removed the `ref:refs/heads/main` subject. It let ungated jobs on `main`
  (no `environment:`, `workflow_dispatch`, `schedule`) assume the apply role without approval. The
  environment subject is now the only trust, and `github_apply_environment` can no longer be null.

## Context
GitHub Actions gets AWS credentials through OIDC: the trust policy on an IAM role checks the `sub`
claim of GitHub's token. Two roles exist in `terraform/bootstrap/github_oidc.tf`:

- `nw-gha-plan` - read-only, trusted for `pull_request` events.
- `nw-gha-apply` - `AdministratorAccess` for now, so it must only be reachable from reviewed code on `main`.

The catch: when a job declares `environment: <name>`, GitHub sends
`repo:OWNER/REPO:environment:<name>` as `sub` instead of `repo:OWNER/REPO:ref:refs/heads/<branch>`.
The branch is no longer in the claim, so a branch condition in the trust policy does not apply to
environment jobs. Any workflow on any branch that declares the environment would match, unless
GitHub itself restricts which branches may deploy to that environment.

## Decision
Trust `nw-gha-apply` for one exact subject: jobs in the `terraform-apply`
GitHub Environment (`github_apply_environment = "terraform-apply"`). The `terraform-apply` environment is
configured in GitHub with:

1. **Deployment branches:** selected branches, `main` only - restores the branch check the token drops.
2. **Required reviewers:** the repo owner - every apply waits for a manual approval.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Protected `terraform-apply` environment subject only, deployments limited to `main` (chosen) | Apply only from `main` and only after approval; visible audit trail of approvals in GitHub | Security depends on settings outside Terraform; extra click per apply |
| Branch subject only (`ref:refs/heads/main`) | Simple; everything is in the trust policy | Every merge applies immediately with no human gate; any ungated job on `main` (`workflow_dispatch`, `schedule`) also gets admin |
| Branch subject + environment subject (original decision, replaced 2026-11-13) | Covers both job shapes | The branch subject bypasses the approval gate, so the gate is only as strong as the weakest subject |
| `terraform-apply` environment with no protection rules | None | Any branch can declare the environment and assume an admin role - worse than no environment |
| Wildcard `sub` such as `repo:OWNER/REPO:*` | Never breaks | Any branch, PR or environment gets admin; fails least privilege |

## Consequences
- An apply needs both a merge to `main` and an approval, so a compromised feature branch cannot reach admin credentials.
- The environment rules live in GitHub settings, not in code. They are recorded here, and
  evidence of them is in `docs/evidence/2026-10-31-apply-environment.png`.
- "Allow administrators to bypass configured protection rules" is left on as a break-glass path:
  with a single owner there is no second approver if the gate itself misbehaves. The cost is that
  the required review is a convention for me, not a hard control; bypassed runs still show in the
  environment's deployment history. Turn it off once a second reviewer exists.
- If the `terraform-apply` environment is deleted or renamed, apply jobs fail closed: the `sub` no longer matches.
- Required reviewers are free only on public repositories; making the repo private on the free plan removes the approval gate.
- Still to do: replace `AdministratorAccess` with a scoped policy once the managed services are known, and
  consider separate apply roles per AWS account (`workloads-dev`, `workloads-prod`) with their own environments.

## Interview angle
"How do you stop a feature branch from running `terraform apply`?" - The apply role trusts only exact
`sub` claims. Because an environment job's token drops the branch, I lock the `terraform-apply` environment
to `main` in GitHub and require my approval, so apply needs a merged change and a human sign-off.
