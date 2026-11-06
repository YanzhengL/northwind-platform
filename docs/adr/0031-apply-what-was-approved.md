# 0031. Re-plan and apply inside the approved job

- **Status:** accepted
- **Date:** 2026-10-31

## Context
A PR shows a plan made against the PR branch. After merge, the pipeline applies `main` once the
`terraform-apply` environment approval is given (ADR 0012). The question is what exactly gets applied:
the plan that was reviewed, or a fresh plan.

Three facts constrain the choice:

- **The plan role can't run after merge.** `nw-gha-plan` trusts only the `pull_request` subject, so
  every post-merge Terraform command uses `nw-gha-apply`, which only an approved environment job (or
  a push to `main`) can assume.
- **A saved plan file holds secrets in plaintext.** `tfplan` contains every input, including values
  Terraform redacts in its text output. On a public repo any signed-in GitHub user can download
  workflow artifacts.
- **Plans go stale.** Another merge, or a change made outside Terraform, between plan and apply makes
  an old plan wrong. Terraform refuses to apply a saved plan if state changed, but cannot detect a
  change that isn't in state yet.

## Decision
On push to `main`, one job per stack runs in the `terraform-apply` environment. After approval it
assumes `nw-gha-apply`, runs `terraform plan -out=tfplan -detailed-exitcode`, writes the plan summary
to the job summary, and runs `terraform apply tfplan` only if there are changes.

The reviewer approves based on the PR's plan comment. `concurrency` (ADR 0030) runs one apply per stack
at a time, so the only gap between the reviewed plan and the applied plan is other merges, which the
reviewer can see.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Re-plan and apply in the approved job (chosen) | No plan file leaves the runner; simple; always applies against current state | Approver sees the PR plan, not the exact post-merge plan; relies on serialised merges |
| Upload the PR's plan as an artifact, apply that exact file | Strongest "applied what was reviewed" guarantee | Plaintext secrets in a public artifact unless encrypted; PR plan is stale after any other merge; cross-workflow artifact plumbing |
| Post-merge plan job, then approve, then apply its artifact | Approver sees the real plan | Plan role can't run on `main`, so the apply role runs before approval; same artifact exposure |
| Encrypt the plan artifact with a key held in a GitHub secret | Keeps the exact-plan guarantee | Extra moving parts and a key to rotate, for a solo repo with serialised merges |

## Consequences
- The job summary of every apply shows what was actually applied, so the audit trail stays complete.
- If a post-merge plan differs from the PR plan in a way the reviewer would not have approved, the
  only safe response is a revert PR. Approval happens before the plan is shown.
- Revisit when the team has more than one merger, or when compliance requires "apply exactly the
  reviewed artifact". Then move to the encrypted-artifact option.

## Interview angle
"How do you know you applied what was reviewed?" - "Strictly, I don't guarantee it, and that's a deliberate trade-off. The apply job re-plans from main after approval, so what's applied can differ from the PR plan if another merge or some drift landed in between. Concurrency means only one apply runs per stack, and the job summary records what was actually applied. If it's wrong, I revert. I accept that because I'm the only merger today, and shipping the saved plan would expose plaintext inputs on a public repo. With more mergers, I'd move to an encrypted plan artifact."
