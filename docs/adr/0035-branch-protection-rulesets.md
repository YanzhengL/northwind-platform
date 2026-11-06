# 0035. Protect `main` with a GitHub ruleset, configured by hand

- **Status:** accepted
- **Date:** 2026-10-31

## Context
Apply runs on push to `main` (ADR 0031), so whoever can change `main` can change AWS. `main` must only
change through a PR whose checks passed.

GitHub has two mechanisms: **classic branch protection** and the newer **rulesets**. Rulesets can
target several branches by pattern, can be viewed by anyone with read access, and list their bypass
actors explicitly.

The repo has one owner. GitHub doesn't allow approving your own PR, so a required approval count
above zero would make every merge impossible without bypass.

The platform rules say no ClickOps: anything set up by hand is imported or recorded in an ADR.

## Decision
One ruleset named `protect-main`, targeting `main`, **active**, with no bypass actors:

- Require a pull request before merging, with **0** required approvals.
- Require status checks to pass, and the branch to be up to date: `ci-ok` only (ADR 0030). It
  aggregates every job in `ci.yml`, so new CI jobs don't need a ruleset change.
- Block force pushes.
- Restrict deletions.

The human gate for infrastructure is the `terraform-apply` environment approval (ADR 0012), not a PR
review. The ruleset is configured in the GitHub UI and recorded here, with a screenshot in
`docs/evidence/`.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Ruleset, by hand, recorded here (chosen) | No extra credentials; visible to reviewers; explicit empty bypass list | Not in code; drift is only caught by looking |
| Classic branch protection | Familiar | Hidden from non-admins; older model GitHub is moving away from |
| `integrations/github` Terraform provider | Settings as code; drift shows in plan | Needs a PAT or GitHub App key, which is a long-lived credential; the pipeline would manage its own protection |
| Require 1 approval | Real four-eyes review | Impossible with one owner without bypass, which makes the rule meaningless |

## Consequences
- A direct `git push origin main` is rejected, including for the owner. This is a Day 3 `Done when` item.
- Required check names must match the job names exactly. Renaming a job silently blocks every merge
  until the ruleset is updated.
- The environment's admin bypass (ADR 0012) is still on, so the one human gate is a convention, not a
  hard control. With a second engineer: require 1 approval here and turn off that bypass.
- Revisit the Terraform provider when there are several repos to keep consistent.

## Interview angle
"How do you stop someone pushing straight to production?" - A ruleset on `main` requires a PR with the
`ci-ok` check passing, blocks force pushes, and has no bypass actors. Apply then
needs an environment approval. I set it up by hand rather than with the GitHub provider, because
managing it as code would need a long-lived token, which this platform avoids.
