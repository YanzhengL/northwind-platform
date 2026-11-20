# 0041. Delegate a DNS subzone to each workload account

- **Status:** accepted
- **Date:** 2026-11-19

## Context
From Week 3, services in the dev cluster need public hostnames and HTTPS. They will be served by
an Application Load Balancer created by the AWS Load Balancer Controller, and later hostnames
will be managed by ExternalDNS. Facts that shape the design:

- An ALB can only use an ACM certificate **from its own account and region**. A certificate in
  `shared-services` cannot be attached to an ALB in `workloads-dev`.
- Recreating a hosted zone gives it new name servers, so the delegation has to be redone, and
  any certificate validated in it has to be validated again. Validation takes minutes.
- `terraform/envs/dev` is destroyed after every session by `make down`.
- The parent domain is owned and registered outside this Terraform, so delegating to AWS is one
  manual NS change at the registrar.
- Later, ExternalDNS in each cluster should only be able to change its own environment's records.

## Decision
- **`nw.<domain>`**: a public hosted zone in `shared-services`. The NS records for it are added
  once at the parent domain by hand; this ADR is the record of that manual step.
- **`dev.nw.<domain>`**: a public hosted zone in `workloads-dev`, delegated by NS records in
  `nw.<domain>`. A wildcard ACM certificate for `*.dev.nw.<domain>` is issued in `workloads-dev`
  (`eu-west-2`) and validated by DNS in the dev zone.
- **All of it lives in `terraform/envs/shared`**, the long-lived DNS stack. It uses two providers
  (`nw-shared`, and an alias for `nw-dev`, see ADR 0040). `make down` never touches it. Both zones
  have `prevent_destroy`.
- `workloads-prod` gets the same shape later: `prod.nw.<domain>`, its own zone and certificate.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Subzone and certificate per account, delegated from a parent zone in a shared account (chosen) | The common AWS multi-account DNS pattern; each account owns its records; ExternalDNS gets a same-account, single-zone permission; certificate is where the ALB needs it | Two hosted zones always on ($1/month); applying the DNS stack needs credentials in two accounts |
| One zone in `shared-services`; workload accounts write records through a cross-account role | One zone to manage; common in small organisations | Certificates must still be issued in each workload account; a cross-account write role lets dev change prod records unless it is scoped carefully |
| One wildcard certificate in `shared-services`, exported and imported into each account | One certificate | ALBs can't use another account's ACM certificate directly; exportable public certificates are a paid feature, and imported certificates are not renewed by ACM |
| DNS at an external provider (for example Cloudflare), certificates from Let's Encrypt via cert-manager | Free certificates; widely used with Kubernetes | The ALB still needs an ACM certificate; another vendor's API token to store and rotate; DNS outside the AWS audit trail |
| Dev zone and certificate inside `terraform/envs/dev` (destroyed each session) | Everything for dev in one stack; nothing persistent | New name servers each session, so re-delegation every `make up`. A Route 53 reusable delegation set keeps the name servers stable, but the certificate is still reissued and validated every session; slower start and more ways to fail |
| Private hosted zones shared across accounts | Good for internal service names | Not reachable from the internet, so no public HTTPS for demos or SLO probes |

## Consequences
- After `make up`, HTTPS works right away: the zone and the issued certificate are already there.
- Dev and prod are isolated at the DNS layer. A mistake in dev can't change `prod.nw.<domain>`.
- Two hosted zones cost about $1/month in total, always on, inside the £20 budget. Queries cost
  a few cents at most.
- `nw.<domain>` is a single point of failure for every environment: deleting it breaks all names.
  `prevent_destroy` and the plan comment from ADR 0061 are the guards.
- The wildcard covers one level only: `api.dev.nw.<domain>` works, `a.b.dev.nw.<domain>` does not.
  Services get flat names.
- The registrar's NS change is outside Terraform. If the `nw.<domain>` zone is ever recreated, the
  NS records at the registrar must be updated by hand.

## In short
Each workload account has its own hosted zone and certificate, because an ALB can only use an
ACM certificate from its own account and region. A parent zone in `shared-services` delegates a
subzone to the dev account with NS records. Both zones and the certificate live in the
long-lived DNS stack, not the dev stack, so `make down` never deletes them and the delegation
and certificate validation are not redone every session. Because each account owns its own zone,
dev can never change prod's records. The two zones cost about $1/month, within budget. The
parent zone is protected by `prevent_destroy`.
