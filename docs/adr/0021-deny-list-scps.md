# 0021. Use deny-list SCPs on top of FullAWSAccess

- **Status:** accepted
- **Date:** 2026-10-24

## Context
Service control policies (SCPs) set the maximum permissions for every principal in a member account,
including admins and the root user. They never grant anything: IAM still has to allow an action, and
the SCP can only take it away. They do not apply to the management account or to service-linked roles.

There are two ways to write them:

- **Deny list:** keep the AWS-managed `FullAWSAccess` policy attached and add policies with explicit
  `Deny` statements for the things that must never happen.
- **Allow list:** detach `FullAWSAccess` and attach policies that `Allow` only the services the
  organization uses. Everything else is implicitly denied.

## Decision
Use deny-list SCPs. Keep `FullAWSAccess` attached and add these guardrails:

| Guardrail | Why |
| --- | --- |
| Deny all actions outside `eu-west-2`, with global services exempt (ADR 0022) | Data residency and cost control: nothing can be started in a region nobody watches. |
| Deny `organizations:LeaveOrganization` | A member account can't escape the guardrails and the budget. |
| Deny stopping, deleting or changing CloudTrail trails and changing the log bucket | The audit trail survives even if an admin role in a member account is compromised. |
| Deny all actions by the root user in member accounts | Root can't be limited by IAM. Day-to-day access is through Identity Center. |

Policies are written with `data "aws_iam_policy_document"` in `terraform/org`, attached to the
`Workloads` OU first, tested, and then attached to `Infrastructure`.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Deny list on top of `FullAWSAccess` (chosen) | Short, readable policies; new AWS services work without an SCP change; each statement maps to one stated risk | New services are allowed by default, so a risky new service isn't blocked until someone adds a deny |
| Allow list (detach `FullAWSAccess`) | Strongest restriction; only approved services work | Every new service (and some hidden dependencies) needs an SCP change first; failures are confusing to debug; slows down 5 product teams |
| No SCPs, rely on IAM only | Nothing to maintain | Any admin, or a compromised admin role, can switch off CloudTrail, use other regions or leave the org |
| Control Tower managed guardrails | Pre-built, AWS-maintained | Requires Control Tower and its AWS Config costs; less control and harder to explain line by line |

## Consequences
- Each deny statement is a guardrail that can be explained and tested. The region lock is proven by
  the `us-east-1` bucket test (`docs/evidence/YYYY-MM-DD-scp-region-deny.png`).
- SCP limits apply: 5,120 characters per policy and 5 SCPs per target (including `FullAWSAccess`).
  Related statements are grouped to stay under them.
- SCPs don't protect the management account. Anything still there (state bucket, CI roles, possibly
  the log bucket) relies on IAM and the controls in ADR 0012 and 0013.
- A bad SCP can block legitimate work across a whole OU. Attaching to `Workloads` first limits the
  impact while testing.
- Cost: SCPs are free.

## To confirm during implementation
- [ ] Whether CI roles or a break-glass role need a principal exemption (`aws:PrincipalArn`) from any guardrail.
- [ ] Exact CloudTrail and S3 actions in the "protect audit trail" statement, and the log bucket ARN.
- [ ] Whether resource control policies (RCPs) are worth adding later for the state and log buckets.

## Interview angle
"Why deny-list SCPs, not allow-list?" - SCPs only limit, never grant. With 5 product teams I didn't want
every new AWS service to need an org-level change, so I kept `FullAWSAccess` and denied the specific
things that must never happen: other regions, leaving the org, tampering with CloudTrail, and root use.
Each one maps to a risk and I tested the region deny. The trade-off is that new services are allowed by
default, and I'd move to an allow list for a regulated workload.
