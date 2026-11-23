# 0041. Delegate a DNS subzone to each workload account

- **Status:** accepted
- **Date:** 2026-11-19
- **Amended:** 2026-11-23 - the parent zone is the registered domain itself (`<domain>`), not
  `nw.<domain>`. The registry delegates only the registered name, and no zone hosted it, so a zone at
  `nw.` would have needed a third zone above it. The subzones are
  renamed to one label, `nw-<env>.<domain>` (was `<env>.nw.<domain>`), matching the resource naming
  convention. One zone and one certificate per workload account is unchanged.

## Context
From Week 3, services in the dev cluster need public hostnames and HTTPS. They will be served by
an Application Load Balancer created by the AWS Load Balancer Controller, and later hostnames
will be managed by ExternalDNS. Facts that shape the design:

- An ALB can only use an ACM certificate **from its own account and region**. A certificate in
  `shared-services` cannot be attached to an ALB in `workloads-dev`.
- Recreating a hosted zone gives it new name servers, so the delegation has to be redone, and
  any certificate validated in it has to be validated again. Validation takes minutes.
- `terraform/envs/dev` is destroyed after every session by `make down`.
- The domain is registered through Route 53 Domains in the management account, outside this
  Terraform. Registration and DNS hosting are separate, so the zone can be in another account;
  connecting them is one manual name-server change at the registrar.
- The registry delegates only the registered name (`<domain>`). No registrar setting can delegate
  `nw.<domain>` directly; that takes NS records in a zone for `<domain>`.
- The domain has no other use. Its registration still listed the name servers of a zone that no
  longer answers (a lame delegation), so moving it breaks nothing and removes a takeover risk.
- Later, ExternalDNS in each cluster should only be able to change its own environment's records.

## Decision
- **`<domain>`**: a public hosted zone in `shared-services`. Its four name servers are set once at
  the registrar by hand, with management credentials; this ADR is the record of that manual step.
- **`nw-dev.<domain>`**: a public hosted zone in `workloads-dev`, delegated by NS records for
  it in the `<domain>` zone. A wildcard ACM certificate for `*.nw-dev.<domain>` is issued in
  `workloads-dev` (`eu-west-2`) and validated by DNS in the dev zone.
- **All of it lives in `terraform/envs/shared`**, the long-lived DNS stack. It uses two providers
  (`nw-shared`, and an alias for `nw-dev`, see ADR 0040). `make down` never touches it. Both zones
  have `prevent_destroy`.
- `workloads-prod` gets the same shape later: `nw-prod.<domain>`, its own zone and certificate.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Subzone and certificate per account, delegated from a parent zone in a shared account (chosen) | The common AWS multi-account DNS pattern; each account owns its records; ExternalDNS gets a same-account, single-zone permission; certificate is where the ALB needs it | Two hosted zones always on ($1/month); applying the DNS stack needs credentials in two accounts |
| A third zone: `<domain>`, then `nw.<domain>`, then `dev.nw.<domain>` (the original shape, plus the apex zone it needs) | Keeps the platform's names apart from any other use of the domain | $0.50/month more and one more delegation that can break, for a domain with no other use |
| One zone in `shared-services`; workload accounts write records through a cross-account role | One zone to manage; common in small organisations | Certificates must still be issued in each workload account; a cross-account write role lets dev change prod records unless it is scoped carefully |
| One wildcard certificate in `shared-services`, exported and imported into each account | One certificate | ALBs can't use another account's ACM certificate directly; exportable public certificates are a paid feature, and imported certificates are not renewed by ACM |
| DNS at an external provider (for example Cloudflare), certificates from Let's Encrypt via cert-manager | Free certificates; widely used with Kubernetes | The ALB still needs an ACM certificate; another vendor's API token to store and rotate; DNS outside the AWS audit trail |
| Dev zone and certificate inside `terraform/envs/dev` (destroyed each session) | Everything for dev in one stack; nothing persistent | New name servers each session, so re-delegation every `make up`. A Route 53 reusable delegation set keeps the name servers stable, but the certificate is still reissued and validated every session; slower start and more ways to fail |
| Private hosted zones shared across accounts | Good for internal service names | Not reachable from the internet, so no public HTTPS for demos or SLO probes |

## Consequences
- After `make up`, HTTPS works right away: the zone and the issued certificate are already there.
- Dev and prod are isolated at the DNS layer. A mistake in dev can't change `nw-prod.<domain>`.
- Two hosted zones cost about $1/month in total, always on, inside the £20 budget. Queries cost
  a few cents at most.
- `<domain>` is a single point of failure for every environment: deleting its zone breaks all names.
  `prevent_destroy` and the plan comment from ADR 0061 are the guards.
- The wildcard covers one level only: `api.nw-dev.<domain>` works, `a.b.nw-dev.<domain>` does not.
  Services get flat names.
- The registrar's name-server change is outside Terraform. If the `<domain>` zone is ever recreated,
  the name servers at the registrar must be updated by hand.
- The platform's zone now owns the whole domain. If the domain is ever used for something else, its
  records go in this zone or in another delegated subzone.

## In short
I set up separate hosted zones and certificates per account, because an ALB can only use an
ACM certificate from its own account and region. The parent zone, for the registered domain itself, is in
`shared-services` and delegates a subzone to the dev account with NS records. Both zones and the certificate live in the
long-lived DNS stack, not the dev stack, so `make down` never deletes them and the delegation
and certificate validation are not redone every session. Because each account owns its own zone,
dev can never change prod's records. The two zones cost about $1/month, within budget. The
parent zone is protected by `prevent_destroy`.
