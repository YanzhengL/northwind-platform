# 0013. Keep the bootstrap stack in the management account for now

- **Status:** accepted
- **Date:** 2026-10-19

## Context
`terraform/bootstrap` creates the foundations every other stack depends on: the S3 state bucket,
the GitHub Actions OIDC provider, and the `nw-gha-plan` / `nw-gha-apply` roles.

The target design puts shared tooling such as state in the `shared-services` account. That account
does not exist yet: it will be created by `terraform/org`, which itself needs a state bucket and
credentials to run. Something has to exist first, and the only account available today is the
management account, reached by SSO with `AdministratorAccess`.

AWS guidance is to keep the management account as empty as possible. Two facts make that matter
here:

- **SCPs do not apply to the management account.** The `eu-west-2`-only guardrail and any other SCP
  will not constrain resources or roles that live there.
- **An admin role in the management account is organisation-wide power.** `nw-gha-apply` has
  `AdministratorAccess`, so it can change Organizations, SCPs and member accounts, not only this
  account.

## Decision
Apply the bootstrap stack in the management account now, and record it as a temporary
location. Move the state bucket and the CI roles to `shared-services` once that account exists.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Management account now, migrate later (chosen) | Unblocks everything today; no extra account to create by hand; migration is a known, reversible procedure | Management account holds non-org resources; SCPs don't protect them; admin CI role has org-wide reach until migrated |
| Create `shared-services` by hand first, bootstrap there | Correct end state from day one | ClickOps account creation that must then be imported; more setup before any code runs |
| Dedicated `bootstrap` / tooling account | Strongest isolation of state and CI identity | One more account to manage for a ~5-person platform; same chicken-and-egg problem |

## Consequences
- The diagram shows the bootstrap resources inside the management account, matching what is deployed.
- Until migration, the apply role's trust policy and the protected `production` environment
  (ADR 0012) are the main controls on org-wide admin access. Keep that environment locked to `main`
  with a required reviewer.
- Cost is unchanged: one S3 bucket holding a few KB of state; IAM and OIDC are free.
- Migration plan, tracked in #4:
  1. Create `shared-services` via `terraform/org`.
  2. Create a new state bucket there and run `terraform init -migrate-state` for each stack.
  3. Create per-account CI roles (see ADR 0012 consequences) and narrow the management-account
     role to the `terraform/org` stack only.
  4. Remove the old bucket and roles from the management account.

## Interview angle
"Why is your Terraform state in the management account?" - Because it had to exist before the
account it belongs in. I bootstrapped in management deliberately, recorded the risks (SCPs don't
apply there, and an admin role there is org-wide), gated the apply role behind `main` plus a
required reviewer, and have a tracked plan to move state and CI roles to `shared-services`.
