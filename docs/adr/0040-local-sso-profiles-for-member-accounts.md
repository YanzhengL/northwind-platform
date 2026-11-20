# 0040. Apply member-account stacks locally with IAM Identity Center profiles

- **Status:** accepted
- **Date:** 2026-11-19

## Context
Until now every stack (`bootstrap`, `org`) has run in the management account: the state bucket
and the CI roles `nw-gha-plan` / `nw-gha-apply` live there (ADR 0013, issue #4). From Week 2 on,
stacks build resources in member accounts:

- `terraform/envs/shared` builds DNS in `shared-services` and `workloads-dev` (ADR 0041).
- `terraform/envs/dev` builds the network and cluster in `workloads-dev`. It is created by
  `make up` and destroyed by `make down` in every working session.

Terraform needs credentials in the target account, and somewhere to keep state. The constraints:

- No long-lived AWS keys anywhere. People use `aws sso login`, CI uses OIDC.
- `terraform/org` already assigns the admin and read-only permission sets to every member
  account, so people can already reach them through IAM Identity Center.
- No CI role exists in any member account yet.
- One person runs every session. `make up` / `make down` are run by a human, not by CI.

## Decision
- **People apply `envs/*` locally** with IAM Identity Center profiles, one per member account:
  `nw-shared` and `nw-dev` (later `nw-prod`). All of them share one `sso-session`, so a single
  `aws sso login` covers every account.
- **State stays in the existing bucket in the management account**, under
  `envs/<env>/terraform.tfstate`. The backend uses the management profile (`profile` in the
  gitignored `backend.s3.tfbackend`); the provider uses the member-account profile
  (`profile = var.aws_profile`). Backend and provider credentials are configured separately.
- **Every provider sets `allowed_account_ids`** (account ID from the gitignored `terraform.tfvars`),
  so running a stack with the wrong profile fails before plan instead of building in the wrong
  account.
- **CI runs the static checks on `envs/*`** (fmt, validate, tflint, Checkov, Trivy) but does not plan
  them yet, because it has no credentials in the member accounts. Until it does (planned in
  ADR 0061, read-only plan roles in each member account), the local `make plan` summary goes in
  the PR description. The gap is stated in a comment next to `all_stacks` in `ci.yml`.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Identity Center profile per account, state in management (chosen) | No new IAM; uses access that already exists; one login covers all accounts; the same pattern AWS recommends for human access | Each stack needs two credential sources (backend and provider); CI cannot plan these stacks until member-account roles exist |
| Provider `assume_role` into a deployment role in each account ("hub and spoke"), from one central identity | Very common in multi-account setups; one credential source; works the same locally and in CI | A deployment role must first be bootstrapped in every account. The shortcut, `OrganizationAccountAccessRole`, gives full admin into each member account from the management account, and AWS advises keeping the management account out of daily use |
| State bucket in each account, next to the resources it describes | Strong isolation: one account's credentials never touch another's state; common with account vending (for example Account Factory for Terraform) | One more bucket and bootstrap per account; more to secure and back up for four accounts |
| Cross-account bucket policy, so member-account roles write to the management bucket | One credential source per stack | Grants member accounts access into the management account; every prefix needs careful scoping, or dev could read the `org` state |
| Remote runner with per-workspace credentials (HCP Terraform, Spacelift, env0, Atlantis) | Industry standard at scale: central audit, policy checks, no local credentials | A new system, and either a SaaS plan or an always-on runner to pay for and secure; too much for one maintainer |
| Terragrunt to generate backend and provider blocks per account | Removes repetition when there are many accounts and environments | A new tool and its own concepts for three stacks |

## Consequences
- Day-to-day work needs no new IAM and no keys: `aws sso login` once, then `make up` / `make down`.
- State for every account sits in the management account. That is one bucket to protect, but it
  is also the account AWS advises using least. Moving state to `shared-services` stays tracked in
  issue #4.
- Applies to `envs/*` have no approval gate like ADR 0012's, because they are local. The review is
  the plan you read before typing `yes`, and the plan summary on the PR.
- Until ADR 0061, a PR that only changes `envs/*` can pass `ci-ok` without any plan in CI. Readers
  must rely on the plan summary in the PR description.
- Profile names (`nw-shared`, `nw-dev`) are a convention the code depends on; they are documented
  in the README quick start. ADR 0061 must reuse the same names in CI so the Terraform code stays
  the same locally and in CI.
- `allowed_account_ids` makes "wrong account" a fast, harmless failure, not a silent one.

## In short
No long-lived keys anywhere. People use IAM Identity Center: one profile per account, all sharing one SSO session, so one login covers all four. CI uses GitHub OIDC, which today only reaches the management account; read-only plan roles in the member accounts are next. State is one S3 bucket in the management account, with one state file per stack. Because the state and the resources are in different accounts, the backend uses the management profile and the provider uses the member-account profile, and `allowed_account_ids` makes a wrong profile fail before plan.
