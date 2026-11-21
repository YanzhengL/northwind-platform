# 0037. Check mandatory tags on PRs

- **Status:** accepted
- **Date:** 2026-11-16
- **Amended:** 2026-11-16 - Infracost tagging policies are a 14-day Infracost Cloud trial, not
  part of the free tier, and the trial will not be extended. The check is proven by
  `docs/evidence/2026-11-16-infracost-tags-pass.png`, then stops when the trial ends. Its
  replacement is the custom Checkov policy from "Alternatives", planned before tenant
  onboarding in Week 3.
- **Amended:** 2026-11-21 - the custom Checkov policy `CKV2_NW_1` replaces Infracost as the
  tag check, and it **blocks the merge**. A `validation` on `var.env` covers the `env` values
  that Checkov cannot see. The Infracost tagging policy is optional and stops when the trial
  ends. See "Decision" and "Consequences"; the original Infracost-based decision is kept
  below them for the record.

## Context
Every AWS resource must carry four tags: `team`, `env`, `service` and `owner`. They drive cost
allocation and ownership. Until now, three layers were involved, and none of them made a PR
fail or warn when a tag was missing:

| Layer | What it does | Catches a missing tag on the PR? |
| --- | --- | --- |
| `default_tags` in each provider | Adds the four tags to every resource the provider creates | No. A stack that leaves out the block is not flagged |
| AWS tag policy `nw-mandatory-tags` | Standardises key spelling and case across the org. Report-only (no `enforced_for`) | No. It reports after the resource exists |
| Infracost tagging policy (default) | Checks every planned resource on the PR | Not usefully. The default policy expected other key names and flagged correctly tagged resources ([evidence](../evidence/2026-11-10-pr-plan-infracost.png)) |

A comment in `terraform/org/tag_policy.tf` also said Checkov enforced the tags. It did not.

## Decision
- `default_tags` in every provider **applies** the tags.
- The Checkov policy `CKV2_NW_1` (`.checkov/policies/mandatory_default_tags.yaml`) **checks
  the keys** and blocks the merge (ADR 0033). It fails any `provider "aws"` block, aliases
  included, that does not set `team`, `env`, `service` and `owner` in `default_tags`.
  - It checks the provider block, not each resource, because Checkov does not merge
    `default_tags` into resources. This is the "extra handling" noted under "Alternatives".
  - An aliased provider does not inherit `default_tags`, so each alias needs its own block.
- A `validation` on `var.env` in every stack **checks the value**: `mgmt`, `shared`, `dev` or
  `prod`. Checkov cannot do this, because the values come from gitignored `terraform.tfvars`
  and are only known at plan time.
- The AWS tag policy stays report-only, as the org-wide spelling standard.
- The Infracost tagging policy is optional and stops when the trial ends.

| Layer | Checks | When | Blocks? |
| --- | --- | --- | --- |
| `CKV2_NW_1` (Checkov) | Every aws provider declares the four keys | pre-commit and CI, before plan | Yes, the merge |
| `var.env` validation | `env` is one of the four account names | `terraform plan` | Yes, the plan |
| AWS tag policy | Key spelling and case | After the resource exists | No, reports only |

### Original decision (2026-11-16, superseded by the amendment above)
- The Infracost tagging policy **checks** the tags on every Terraform PR. It requires the keys
  `team`, `env`, `service` and `owner`, and limits `env` to `mgmt`, `shared`, `dev` and `prod`.
  The other three values are free text.

The Infracost policy lives in Infracost Cloud, not in this repo, so its settings are recorded here:

| Setting | Value |
| --- | --- |
| Required keys | `team`, `env`, `service`, `owner` (lowercase, as in `tag_policy.tf`) |
| `env` allowed values | `mgmt`, `shared`, `dev`, `prod` |
| Other keys | Free text |
| Default "FinOps tags" policy | Replaced by this one |

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Infracost tagging policy (chosen) | Already runs on every Terraform PR; reads the plan, so it sees tags added by `default_tags`; no code to maintain | Config lives in a SaaS UI, not in Git; advisory only, because the `infracost` job is non-blocking (ADR 0033) |
| Custom Checkov policy (YAML) in the repo | Free, versioned in Git, and blocks the merge (Checkov is the blocking tool) | One more policy to maintain. Checkov scans HCL before a plan exists, so tags that come from `default_tags` need extra handling to avoid false failures |
| `enforced_for` in the AWS tag policy | Native AWS control | Covers only some resource types, and fails at apply time after merge, not on the PR |
| OPA / conftest on the plan JSON | Most flexible, and fully in Git | A new tool and language for four keys; overkill at this scale |
| `validation` block on `var.env` | Free, in-repo, fails at `plan` | Covers one stack's variable only; doesn't catch a stack that forgets `default_tags` |

## Consequences
- A PR that adds or changes an aws provider without the four tags **cannot merge**, and the
  same check fails locally in `make lint` before the push.
- The policy is in Git, so a change to it is reviewed in a PR like any other code. Tests in
  `tests/checkov/` (`make test`) prove it passes a fully tagged provider and fails missing
  tags, missing `default_tags` and an untagged alias.
- `CKV2_NW_1` proves the keys exist, not that the values are sensible: `owner = ""` passes. The
  `var.env` validation covers `env`; the other three values are free text and rely on review.
- New stacks must copy the `default_tags` block and the `var.env` validation. Checkov catches a
  missing block; a missing validation is only caught in review.
- The pre-commit hook runs Checkov from inside each stack folder, so it is given the policy
  folder as an absolute path; a relative path there silently skips the policy.

### Original consequences (2026-11-16, superseded)
- Missing or misspelt tags show on the PR, in the Infracost comment, before anything exists in AWS.
- The check is **advisory**: a PR with missing tags can still merge. The reviewer, and the £20
  budget alarm afterwards, are the backstop. Revisit when product teams open their own PRs
  (Week 3 tenant onboarding). A custom Checkov policy would make it blocking.
- The policy is configured outside Git. A change in Infracost Cloud does not show up in a PR, so
  this ADR must be updated by hand when the settings change.

## Interview angle
**"How do you enforce tagging?"** AWS tag policies don't make a tag mandatory; they only
standardise the spelling. So every provider applies the four tags through `default_tags`, and
Infracost checks every planned resource on the PR, before anything exists in AWS. It's advisory
today because Checkov is my only blocking tool. Once other teams open PRs, I'd add a custom
Checkov policy to block. I chose to check on the PR rather than at apply time because a failure
after merge is the most expensive place to find a missing tag.
