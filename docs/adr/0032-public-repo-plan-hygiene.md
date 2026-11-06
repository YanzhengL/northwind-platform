# 0032. Keep account IDs and personal data out of public CI output

- **Status:** accepted
- **Date:** 2026-10-31

## Context
The repo is public, so its workflow logs, job summaries, artifacts and PR comments are public too.
A Terraform plan of `terraform/org` would print:

- AWS account IDs inside ARNs,
- the organization ID (`o-...`),
- each member account's root-recovery email (whoever controls that inbox can reset root),
- Identity Center usernames.

The platform rules forbid publishing account IDs, and these inputs live in gitignored `terraform.tfvars` and
`*.tfbackend` files, so CI has no copy of them yet.

Two GitHub behaviours constrain where those inputs can live:

- **Environment secrets need `environment:` on the job, and that changes the OIDC `sub`** to
  `environment:<name>`. The PR plan job would no longer match `nw-gha-plan`'s `pull_request` trust.
- **Masking is by exact string.** GitHub masks registered secrets, but a multi-line secret such as a
  whole tfvars file is not reliably masked line by line, and values derived from secrets are not
  masked at all.

## Decision
1. **Inputs are repository secrets**: one tfvars secret per stack (`TFVARS_ORG`, `TFVARS_BOOTSTRAP`),
   `TF_STATE_BUCKET`, and the role ARNs `AWS_PLAN_ROLE_ARN` and `AWS_APPLY_ROLE_ARN`, which contain the
   account ID. Jobs write the tfvars to files and never echo any of them.
2. **Mask identifiers first.** The first step after OIDC login reads every account ID, the organization
   ID, the account emails and the Identity Center usernames from live AWS and registers each with
   `::add-mask::`. ARNs then show `***`, and a new member account is masked with no workflow change. If
   a lookup fails, the job stops before Terraform prints anything.
3. **Let Terraform redact the rest.** Mark `organization_id`, `budget_alert_emails` and
   `sso_admin_usernames` `sensitive = true`, along with the `organization_id` output. `accounts` holds
   the emails, but `sensitive` applies to a whole variable, and Terraform refuses a sensitive value in
   `for_each`. So mark `accounts` sensitive too, and iterate over
   `nonsensitive(toset(keys(var.accounts)))`: the account names are not secret, the emails stay
   redacted. The same wrapper is needed where `keys(var.accounts)` feeds Identity Center assignments,
   and `sso_admin_usernames` needs `nonsensitive()` for the same reason.
4. **The PR comment is a summary**: resource address and action (create, update, replace, delete) from
   `terraform show -json`, not the full diff. Usernames are removed from Identity Center addresses,
   because GitHub does not mask PR comments.
5. **The job log shows `terraform show`, not raw plan output.** `terraform plan` stdout is discarded
   because `Refreshing state... [id=...]` prints raw IDs for every resource. `terraform show` omits those
   lines, and steps 2-3 redact what remains. Apply strips `[id=...]` from its progress lines.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Repository secrets + masking + `sensitive` + summary comment (chosen) | Free; plan role trust unchanged; reviewer still sees what changes | Relies on discipline: a new input must be marked sensitive or it can leak |
| Make the repo private | Nothing is public | Loses the CV value of the repo; Actions minutes are billed after the free quota; environment reviewers need a paid plan |
| Environment secrets for plan inputs | Secrets scoped to the gate | Changes the plan job's `sub`; the plan role would need an environment subject too |
| SSM Parameter Store SecureString read by the role | Inputs stay in AWS, versioned; standard tier is free | Plan role needs `kms:Decrypt` and `ssm:GetParameter`, which is a bootstrap change; another place to manage config |
| Post the full plan diff as the comment | Richest review | Publishes anything not caught by masking |

## Consequences
- Every new variable that holds an ID, email or name must be reviewed for `sensitive = true`. Add this
  to the PR template checklist.
- The `Done when` wording in the roadmap changes from "logs show the assumed-role ARN" to "logs show
  `arn:aws:sts::***:assumed-role/nw-gha-apply/...`", which still proves OIDC and the role name.
- Before saving evidence screenshots, check them for unmasked IDs: masking applies to logs, not to the
  AWS console.
- Marking existing values sensitive makes the next plan show in-place updates, once. The values don't
  change, only their sensitivity marking in state, so the plan is not empty until that change is applied.
- `nw-gha-plan` and `nw-gha-apply` must be able to read Organizations and Identity Center, or the mask
  step fails and the job stops.

## Interview angle
"Your repo is public. How do you stop your plan leaking account details?" - Inputs come from repository
secrets, account IDs and other identifiers are read from AWS and masked at runtime, identifying inputs
are marked sensitive so Terraform redacts them, and raw plan output never reaches the log. The PR
comment lists only addresses and actions, because GitHub doesn't mask comments. I kept the inputs out of
environment secrets because that changes the OIDC subject the plan role trusts.
