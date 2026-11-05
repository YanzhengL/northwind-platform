# 0033. Checkov blocks merges; Trivy and Infracost report

- **Status:** proposed
- **Date:** 2026-10-31

## Context
The platform security requirements call for Checkov and Trivy in CI and Infracost on Terraform PRs. What's left to decide is
which tools **block** a merge and which only **inform**, and how findings reach the PR.

- **Checkov** is step 4 of the `static` job in `ci.yml` (ADR 0030). A failing step only shows a red X,
  though. The Day 3 evidence needs findings visible on the PR.
- **Trivy** (`trivy config`) overlaps with Checkov on Terraform, but it is also the scanner for
  container images from Week 4.
- **Infracost** estimates the monthly cost difference of a PR. Most of what exists today
  (Organizations, the first CloudTrail trail, a small S3 bucket) is close to £0, so its numbers only
  become useful in Week 2.

## Decision
| Tool | Where | Blocks merge? | How the PR shows it |
| --- | --- | --- | --- |
| Checkov | `static` job, step 4, Checkov CLI (text and SARIF output) | **Yes**, and `plan` is skipped | Failed check, plus code scanning annotations on the diff |
| Trivy config | `static` job, after Checkov, SARIF output | No | Code scanning annotations and Security tab |
| Infracost | `infracost` job | No | One PR comment, updated in place |

Checkov runs once. Its CLI is called directly rather than through the pre-commit hook, because CI needs
SARIF output. Both the hook (on the laptop) and the CLI (in CI) read `.checkov.yaml`, so the rules and
settings are the same. The SARIF upload step uses `if: always()`, so findings reach the PR even when
Checkov fails the job.

Accepted Checkov risks are skipped **inline only**, with a reason and an issue link, as on
`CKV_AWS_274` today. No `--skip-check` flags in config, and the hook is never disabled.

Code scanning is free on public repos and needs `security-events: write` on the reporting job only.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Checkov blocks, Trivy and Infracost report (chosen) | One enforcing tool, so there is one place to manage skips; findings visible inline; no credentials issued for code that fails it | Plan output is only seen once Checkov passes, so a finding must be fixed or skipped with a reason first |
| Both Checkov and Trivy block | Wider coverage | Two skip syntaxes for overlapping rules; double the noise |
| Trivy only (it replaced tfsec) | One tool for IaC and images | Checkov is a platform requirement; existing skips (`CKV_AWS_274`) use Checkov syntax |
| Infracost blocks above a threshold | Hard cost guardrail | Today's numbers are ~£0; a gate would be tuned blind. The £20 budget alarm is the real backstop |

## Consequences
- The Day 3 `Done when` item "PR shows Checkov comment" becomes "Checkov findings visible on the PR".
- Trivy findings start as advisory. Promote to blocking for HIGH/CRITICAL once the noise is known,
  ideally when image scanning arrives in Week 4.
- Infracost needs `INFRACOST_API_KEY` as a repository secret. It is not an AWS key, so the
  no-long-lived-keys rule is not broken, but it is rotated like any other secret.

## Interview angle
"What stops an insecure change from merging?" - Checkov runs as a required check and blocks.
Exceptions are inline with a reason and an issue, so they're auditable. Trivy and Infracost report on
the PR so the reviewer sees security and cost before approving, without one tool's noise blocking work.
