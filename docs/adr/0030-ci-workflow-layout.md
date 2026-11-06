# 0030. One CI workflow: static checks in order, then credentials only for plan and apply

- **Status:** accepted
- **Date:** 2026-11-03

## Context
Day 3 makes every infrastructure change linted, scanned, planned and costed on the PR, then applied
by the pipeline through OIDC.

The repo already has `.github/workflows/lint.yml`. It came with the initial scaffold commit and was
never a design decision. It runs `pre-commit run --all-files`, which runs every hook and reports every
failure, so there is no order and no way to stop before an expensive step. It also uses tag-pinned
actions and installs tools without versions.

The standard Terraform CI sequence is `fmt -check` → `validate` → tflint → Checkov → `plan`. Only plan
needs AWS credentials, and only plan has a hard dependency (it runs validation internally). The rest of
the order is by cost: cheapest first, no-credential checks before the credentialled one.

| # | Step | What it does | Credentials | Cost | Hard dependency |
| --- | --- | --- | --- | --- | --- |
| 1 | `terraform fmt -check` | Checks files match the standard layout. Text only. | None | < 1 s | None |
| 2 | `terraform validate` | Checks syntax, references and argument types against provider schemas. Needs `init -backend=false`. | None | Seconds, plus provider download (cached) | None |
| 3 | tflint | Finds valid-but-wrong code: bad instance types, deprecated syntax, unused variables. | None (deep-check mode off) | Seconds | Soft: parses HCL itself |
| 4 | Checkov | Checks HCL against security and compliance rules (ADR 0033). | None | 10-30 s | Soft: parses HCL itself |
| 5 | `terraform plan` | Reads state and real AWS resources, computes the changes. | OIDC → `nw-gha-plan`; writes `.tflock` | 30 s to minutes, holds the state lock | Step 2 |

Other forces:

- **Repo-wide checks.** gitleaks, whitespace hooks and ruff are not Terraform checks, but gitleaks must
  run on every PR from Day 3, not only on Terraform changes.
- **Stacks.** `terraform/bootstrap` and `terraform/org` exist now, and `terraform/envs/*` arrive in
  Week 2. Bootstrap manages the OIDC roles CI itself uses, so CI must never apply it.
- **Required checks and path filters.** A workflow skipped by `on.paths` never reports a status, so a
  required check that points at it stays "pending" and blocks the merge forever.

## Decision
Delete `lint.yml` and add one workflow, `.github/workflows/ci.yml`, that runs on every PR and every
push to `main`:

| Job | Needs | Credentials | Does |
| --- | --- | --- | --- |
| `static` | - | None | One step per check, so the first failure stops the rest: **0** repo checks (gitleaks, generic hooks, ruff, actionlint, zizmor) → **1** fmt → **2** validate → **3** tflint → **4** Checkov, then Trivy config (report only, ADR 0033). |
| `changes` | - | None | Outputs the changed stacks as a matrix. Path filtering happens here, not in `on.paths`. |
| `plan` | `static`, `changes` | `nw-gha-plan` | **5** plan per changed stack, on PRs. Summary to the PR comment (ADR 0032). |
| `infracost` | `static`, `changes` | Infracost key only | Cost diff comment on PRs (ADR 0033). |
| `apply` | `static`, `changes` | `nw-gha-apply` | On push to `main`, per stack except `bootstrap`, in the `terraform-apply` environment (ADR 0031). |
| `ci-ok` | all | None | `if: always()`; fails if any needed job failed or was cancelled. The only required check (ADR 0035). |

Rules:

- **Check config lives in `.pre-commit-config.yaml`.** Steps 0-3 call one hook each
  (`pre-commit run <hook-id> --all-files`), so versions and arguments are identical on the laptop and
  in CI. Checkov runs its CLI directly because CI needs SARIF output, and both read `.checkov.yaml`.
- **No credentials before step 5.** A failure in steps 0-4 skips `plan` and `apply`, so no AWS role is
  assumed for code that hasn't passed static checks, including the security gate.
- **Stack policy.** `bootstrap` is plan only. Its changes are applied by a human with `make bootstrap`.
  `org`, and later `envs/*`, are planned on PRs and applied on merge (`envs/dev` is decided in ADR 0061).
- **Concurrency.** `concurrency: terraform-<stack>` with `cancel-in-progress: false` on plan and apply.
  Cancelling an apply halfway leaves a state lock and partly applied changes.
- **One workflow grows by jobs.** Later CI (pytest for `tools/`, manifest validation for `gitops/`,
  Kyverno tests) is added as jobs in `ci.yml` that `ci-ok` also needs. `app-ci.yml` (Day 11) is
  separate because it builds and pushes images.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| One `ci.yml`, ordered steps from pre-commit hooks (chosen) | Enforced order; no credentials before checks pass; check config defined once; one required check | Every PR runs the static job, including Python-only ones (cheap); Checkov config split between hook and `.checkov.yaml` |
| `checks.yml` (pre-commit) + `terraform.yml` (plan/apply) | Clear split between no-credential and credentialled work | Workflows run in parallel, so plan runs even when fmt fails; GitHub can't make one workflow wait for another except via clumsy `workflow_run`; two required checks |
| One `terraform.yml` with fmt/validate/tflint/Checkov as raw commands | Matches the textbook sequence exactly | Check versions and arguments duplicated in pre-commit and YAML, so local and CI drift; repo-wide gitleaks needs another workflow |
| Each check as a separate job with `needs:` | Each check is its own PR status | A fresh runner per job adds 20-30 s of checkout and setup each, for no extra safety |
| Atlantis, HCP Terraform or Spacelift | Mature plan/apply UX, locking, policy | Atlantis needs an always-on server; the SaaS options add another trust boundary and account |

## Consequences
- `nw-gha-plan` has `ReadOnlyAccess`, so any PR from a branch in this repo can read state. This is
  acceptable while only the owner can push branches. Fork PRs get no OIDC token.
- Adding a stack means adding it to the `changes` filter. Forgetting means it is silently never planned,
  so the filter list sits next to the matrix and is checked in review.
- Required check names must match job names. Renaming `ci-ok` blocks every merge until the ruleset is
  updated (ADR 0035).

## Interview angle
"Walk me through your Terraform CI." - One workflow. On a PR, a static job runs gitleaks, then fmt, validate, tflint and Checkov in order, cheapest first, with no credentials. Only if they pass does plan assume a read-only role through OIDC; its one write is the state lock file. After merge, apply re-plans with a separate role, behind an environment approval. Hook arguments live in pre-commit, so my laptop and CI run the same checks, except Checkov, which CI calls directly for SARIF. One always-running gate job is the required check, so path filtering never blocks a merge.
