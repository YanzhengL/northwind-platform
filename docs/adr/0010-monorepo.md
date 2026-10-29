# 0010. One monorepo for infrastructure, GitOps config and apps

- **Status:** accepted
- **Date:** 2026-10-12

## Context
A solo builder is creating a portfolio platform that employers will review in a few minutes.
Real organisations usually separate application code from GitOps deployment config.

## Decision
Keep Terraform, GitOps manifests, apps, tools and docs in one repository, `northwind-platform`.
CI uses path filters so each pipeline only runs for its folder.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Monorepo (chosen) | One link shows everything; atomic cross-cutting changes; one place for docs and CI | Weaker separation of duties; app commits are visible to Argo CD; needs path filters |
| Two repos (platform + apps) | Mirrors common practice; cleaner permissions | Two places to review; harder to show the full story |
| Four repos | Strongest isolation | Slow for one person; fragmented portfolio |

## Consequences
Faster iteration and a clearer portfolio. In production I would move `gitops/` to its own repo so
application developers cannot change deployment config directly and app commits do not trigger syncs.

## Interview angle
"Why a monorepo?" â€” portfolio clarity and solo speed now; I know when and why I'd split it.
