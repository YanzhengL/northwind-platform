# 0036. Trust GitHub's immutable OIDC subject claims

- **Status:** accepted
- **Date:** 2026-11-10
- **Updates:** 0012 (the subjects it lists now use the immutable form)

## Context
The CI roles in `terraform/bootstrap/github_oidc.tf` trust exact `sub` claims with `StringEquals`
(ADR 0012). They were written for GitHub's name-based format, for example
`repo:OWNER/REPO:pull_request`.

This repository has **immutable subject claims** enabled. GitHub then adds the numeric owner and
repository IDs to the `sub` claim:

```
repo:OWNER@OWNER_ID/REPO@REPO_ID:pull_request
```

The two formats never match, so every `AssumeRoleWithWebIdentity` call failed. Nobody noticed
until a PR first changed a Terraform stack. Earlier PRs skipped `plan` because no stack had changed,
and `ci-ok` treated the skipped jobs as passing. The first real plan failed with
`Not authorized to perform sts:AssumeRoleWithWebIdentity`.

The setting can be read with
`gh api repos/OWNER/REPO/actions/oidc/customization/sub` (`"use_immutable_subject": true`).

## Decision
Trust the immutable format. `github_owner_id` and `github_repo_id` are new bootstrap inputs. The
plan and apply subjects are built from
`repo:${github_owner}@${github_owner_id}/${github_repo}@${github_repo_id}`. Matching is still exact,
with no wildcards. Both IDs are public, so they are recorded in the tfvars example and are not secrets.

Immutable subjects are switched on in GitHub, not in Terraform, so this ADR records that setting.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Trust the immutable format (chosen) | Trust is tied to this exact repo and owner. If the repo or account is deleted and the name is taken again, the new one cannot assume the roles | Two more inputs; claims are harder to read |
| Turn immutable subjects off | No Terraform change; claims are easy to read | Weaker. Trust follows a name, and names can be reused after deletion |
| Name-based `sub` plus extra `repository_id` / `repository_owner_id` conditions | Same protection as the immutable format; readable `sub` | Only works while immutable subjects are off. More conditions to keep in step with each other |
| `StringLike` with a wildcard on the ID part | Works with either format | Wildcards in trust policies are what ADR 0012 rules out, and they are easy to make too broad |

## Consequences
- `plan` can authenticate. Because CI never applies the bootstrap stack, the trust change is applied
  locally with `make bootstrap` (ADR 0013).
- Renaming the repo or the owner still breaks trust, because the names are also in the claim. It now
  fails closed, and the fix is a tfvars change.
- Transferring the repo to another owner changes the owner ID. The trust has to be updated before CI
  works again.
- The `TFVARS_BOOTSTRAP` secret has to carry the new inputs, or `plan (bootstrap)` fails.
- Lesson for CI design: a check that only runs on some PRs can stay broken for days without anyone
  noticing. Every role or path a pipeline depends on needs at least one real run before it is
  trusted. The apply role's new trust is first tested on the next merge that changes the `org` stack.

## Interview angle
"Your OIDC role worked in theory but failed in CI. How did you debug it, and what did you change?"
I read the job log, which said `AssumeRoleWithWebIdentity` was not authorised. I compared the `sub`
the trust policy expects with what GitHub actually sends, using the repo's OIDC customisation API.
GitHub was sending the immutable format, with numeric owner and repo IDs. I kept exact matching and
added the IDs to the trust policy instead of switching the feature off. That also protects against
someone re-registering the repo name after it is deleted.
