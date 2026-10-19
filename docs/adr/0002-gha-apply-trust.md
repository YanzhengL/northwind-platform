# 0002. Gate the apply role behind a protected GitHub Environment

- **Status:** accepted
- **Date:** 2026-10-16

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
Trust `nw-gha-apply` for two exact subjects: pushes to `main` and jobs in the `production`
GitHub Environment (`github_apply_environment = "production"`). The `production` environment is
configured in GitHub with:

1. **Deployment branches:** selected branches, `main` only - restores the branch check the token drops.
2. **Required reviewers:** the repo owner - every apply waits for a manual approval.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| `main` + protected `production` environment (chosen) | Apply only from `main` and only after approval; visible audit trail of approvals in GitHub | Security depends on settings outside Terraform; extra click per apply |
| `main` only (`github_apply_environment = null`) | Simple; everything is in the trust policy | Every merge applies immediately with no human gate |
| `production` environment with no protection rules | None | Any branch can declare the environment and assume an admin role - worse than no environment |
| Wildcard `sub` such as `repo:OWNER/REPO:*` | Never breaks | Any branch, PR or environment gets admin; fails least privilege |

## Consequences
- An apply needs both a merge to `main` and an approval, so a compromised feature branch cannot reach admin credentials.
- The environment rules live in GitHub settings, not in code. They are recorded here, and
  evidence of them should be captured in `docs/evidence/` (screenshot of the environment settings).
- If the `production` environment is deleted or renamed, apply jobs fail closed: the `sub` no longer matches.
- Required reviewers are free only on public repositories; making the repo private on the free plan removes the approval gate.
- Still to do: replace `AdministratorAccess` with a scoped policy once the managed services are known, and
  consider separate apply roles per AWS account (`workloads-dev`, `workloads-prod`) with their own environments.

## Interview angle
"How do you stop a feature branch from running `terraform apply`?" - The apply role trusts only exact
`sub` claims. Because an environment job's token drops the branch, I lock the `production` environment
to `main` in GitHub and require my approval, so apply needs a merged change and a human sign-off.
