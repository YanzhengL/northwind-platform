# 0034. Pin everything the pipeline runs, and give each job only the permissions it needs

- **Status:** accepted
- **Date:** 2026-10-31

## Context
The apply job holds an admin role in the management account (ADR 0013, #3). Anything that runs in
that job (third-party actions, downloaded tools, providers) runs with that power. So the pipeline's own
dependencies are part of the attack surface.

- **Action tags can be moved.** In March 2025 the tags of `tj-actions/changed-files` were repointed at
  a malicious commit that dumped CI secrets into public logs. Any workflow using `@v45` ran it.
- **Unpinned tools drift.** `lint.yml` installs `checkov` and `pre-commit` without versions, so a
  green build today says nothing about tomorrow's.
- **Workflow-wide permissions are too broad.** `pull-requests: write` or `id-token: write` set at the
  top apply to every job, including ones running third-party code that needs neither.

## Decision
1. **Actions pinned by full commit SHA**, with the version in a comment
   (`uses: actions/checkout@<sha> # v4.2.2`). Dependabot (`github-actions` ecosystem, weekly) opens
   PRs to update them, so pinning doesn't mean never updating.
2. **Tools pinned to exact versions**: Terraform in `setup-terraform`, tflint, Checkov, Trivy,
   Infracost. Pre-commit hooks are pinned by SHA with `pre-commit autoupdate --freeze`.
3. **Provider lockfiles committed with hashes for every platform that runs Terraform**:
   `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`. CI then fails if a provider
   binary doesn't match.
4. **Least-privilege tokens.** `permissions: {}` at workflow level. Each job declares only what it
   uses: `contents: read` on jobs that check out code, `id-token: write` only on `plan` and apply,
   `pull-requests: write` only on the jobs that comment (`plan`, `infracost`), and
   `security-events: write` only on `static`, which uploads SARIF. Permissions apply per job, not per
   step, so every step in a job shares them. `actions/checkout` uses `persist-credentials: false`.

5. **Workflows are linted.** `actionlint` (syntax and expression errors) and `zizmor` (security
   mistakes such as script injection from PR titles, over-broad permissions, unpinned actions) run as
   pre-commit hooks in step 0 of the `static` job (ADR 0030).

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| SHA pins + Dependabot (chosen) | Immutable references; updates still arrive as reviewable PRs | Pins are unreadable without the version comment; more PRs |
| Major version tags (`@v4`) | Readable; automatic fixes | Tags are mutable, which is exactly the tj-actions failure |
| Vendor or fork every action | Full control | Maintenance burden for a solo repo |
| Renovate instead of Dependabot | Groups updates, also handles pre-commit and Terraform | Extra app to install; Dependabot is built in and covers Actions |

## Consequences
- `lint.yml` is removed (ADR 0030), so its unpinned actions and tools go with it.
- Dependabot PRs go through the same checks and need the same review. A SHA bump is still a code change.
- Terraform's own version is pinned exactly in CI but kept as a range in `required_version`, so the
  laptop and CI can differ by patch version. Align them if a bug ever shows up in only one place.
- `plan` holds both `id-token: write` and `pull-requests: write` because it posts its own summary
  comment (ADR 0030), so any step in that job can reach both. A separate comment job would remove the
  overlap, at the cost of passing the summary between jobs.
- Every step in `static` gets `security-events: write`, including the Checkov and Trivy runs, because
  the SARIF upload is a step in that job (ADR 0033).

## Interview angle
"How do you secure the pipeline itself?" - Every action is pinned to a commit SHA because tags can be
moved, as happened with tj-actions in 2025, and Dependabot keeps the pins current. Tools and providers
are version-locked with hashes. Tokens are scoped per job, so the Infracost job can comment on a PR but
can't get AWS credentials. The `plan` job is the exception: it has both, because it posts its own summary.
