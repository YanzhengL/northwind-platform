# 0022. Region lock to eu-west-2 and which global services it exempts

- **Status:** accepted
- **Date:** 2026-10-24

## Context
The platform runs only in `eu-west-2` (London). An SCP enforces this (ADR 0021) with a `Deny` on
`aws:RequestedRegion` not equal to `eu-west-2`.

Some AWS services are global. Their API calls are served from a single endpoint, usually
`us-east-1`, so `aws:RequestedRegion` is `us-east-1` even when the caller is in London. A plain
region deny would break IAM, Organizations, billing and support for every principal in the account.

## Decision
Deny every action where `aws:RequestedRegion` is not `eu-west-2`, using `NotAction` so the
global services below are not matched by the deny. There are no principal exemptions: admins
are locked too.

Start with the smallest list that works, and add a service only after a real failure. Record each
addition and the reason in the table below.

| Exempt (`NotAction`) | Why it's global or needs `us-east-1` |
| --- | --- |
| `iam:*` | IAM is a global service. |
| `organizations:*` | Organizations API is served from `us-east-1`. |
| `sts:*` | The global STS endpoint resolves to `us-east-1`. Regional STS in `eu-west-2` is preferred anyway. |
| `route53:*` | Route 53 hosted zones and records are global. |
| `cloudfront:*` | CloudFront distributions are global. |
| `support:*` | AWS Support API is served from `us-east-1`. |
| `budgets:*` | Budgets API is global. Budget alarm and import must keep working. |

### Exemptions added after testing
| Date | Action(s) | Failure seen | Reason |
| --- | --- | --- | --- |
| | | | |

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Minimal `NotAction` list, grown from real failures (chosen) | Every exemption is justified and explainable; smallest possible hole | Some console pages or CLI calls may fail at first until the list is tuned |
| Copy AWS's full example list (~40 services) | Fewer surprises up front | Exempts services the platform never uses (Chime, Alexa for Business, Global Accelerator); hard to justify each line |
| Allow a second region (e.g. `eu-west-1`) for DR | Room for cross-region backups | Not needed at this size; doubles where resources can hide and cost |
| Exempt admin roles from the region lock | Admins never get blocked | Removes the guardrail exactly where a compromised credential would do most damage |

## Consequences
- Resources can only be created in London, except for the exempt global services, so nothing runs
  unseen in another region.
- Anything that needs `us-east-1` is blocked unless exempted: for example ACM certificates for
  CloudFront, or `ce:*` (Cost Explorer) and `health:*`. Add these only if the platform uses them,
  and record them in the table above.
- `NotAction` exempts actions, not principals, so the exemption list is the same for everyone.
- The management account is not covered (SCPs don't apply there), so the region rule for management
  depends on discipline and the provider `region` setting.
- Cost: free.

## To confirm during implementation
- [ ] Run the `us-east-1` `aws s3 mb` test from `workloads-dev` and save the screenshot.
- [ ] Check that `aws sts get-caller-identity`, the Identity Center portal login and the billing console still work in member accounts.
- [ ] Decide whether `ce:*`, `health:*`, `acm:*` or `s3:ListAllMyBuckets` need exempting.

## Interview angle
"What does your region lock exempt, and why?" - Global services: IAM, Organizations, STS, Route 53,
CloudFront, Support and Budgets, because their API calls are made to `us-east-1` regardless of where
you are. I used `NotAction` with `aws:RequestedRegion` and started with the smallest list, adding a
service only when a real call failed and recording why. Admins aren't exempt, because a stolen admin
credential is exactly what the guardrail is for.
