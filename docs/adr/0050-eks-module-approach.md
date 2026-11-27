# 0050. Write our own EKS module, and keep Helm releases in a separate stack

- **Status:** accepted
- **Date:** 2026-11-25

## Context
Dev needs an EKS cluster that `make up` creates and `make down` destroys in every session. Building it
raises four linked questions: who writes the module, where Helm releases live, whether CI can use
the cluster, and which KMS key encrypts Kubernetes data.

The constraints:

- The scope is small: one cluster, one managed node group, four add-ons (VPC CNI, CoreDNS, kube-proxy and the Pod Identity Agent) and Pod Identity
  associations. One person maintains the platform.
- The public cluster endpoint accepts only the maintainer's IP. GitHub-hosted runners cannot reach it.
- `envs/*` are applied locally (ADR 0040). The planned ADR 0061 lets CI plan `envs/dev`, but never
  apply it. Applications are deployed by Argo CD, which runs inside the cluster.
- Everything in `envs/dev` must be destroyable, within a £20/month budget.

Approximate cost while the cluster runs (check the AWS pricing pages before relying on it): control
plane $0.10/h, two `t3.medium` nodes $0.10/h, NAT gateway and its address $0.055/h (ADR 0042), and
an ALB $0.025/h while one exists. That is about $0.28/h, excluding disks, logs, data and the KMS key.

## Decision
1. **We write `terraform/modules/eks` ourselves**, using `hashicorp/aws` resources directly.
2. **Helm releases live in a second stack, `terraform/envs/dev-k8s`**, with its own state. AWS
   resources, including IAM roles and Pod Identity associations, stay in `envs/dev`. It holds only
   platform components; product apps reach the cluster through Argo CD. CI runs static
   checks on the second stack but does not plan it. `make up` applies `envs/dev` first;
   `make down` removes Ingresses, then the Helm stack, then `envs/dev`.
3. **`nw-gha-apply` gets no access entry.** Authentication mode is `API`, and only the maintainer's SSO
   admin role is given cluster admin.
4. **The KMS key is per session in dev and persistent in prod.** The module takes a key ARN as
   input, so the caller chooses the key's lifecycle. The prod key must live outside the stack that
   `make down` destroys; its location is decided when prod is built. Dev uses a customer key, not
   the free AWS-owned default, so that every session tests the encryption configuration prod will
   use. The cost is under 1p per session.

## Alternatives considered

**Module**

| Option | Pros | Cons |
| --- | --- | --- |
| Own module (chosen) | Only what we use; no hidden defaults; every line can be reviewed | We track AWS changes, fix edge cases and own upgrades |
| `terraform-aws-modules/eks`, pinned | Free, widely used, maintained; faster to build | Large surface; defaults to learn and override; breaking major versions; third-party code runs with our credentials |

**Helm releases**

| Option | Pros | Cons |
| --- | --- | --- |
| Separate stack (chosen) | CI can still plan the network and cluster; the Helm provider doesn't depend on a cluster created in the same apply | No CI plan for Helm changes; two states and a fixed order |
| Same stack as the cluster | One state, one apply | While the cluster is up, CI cannot refresh `helm_release`, so the whole plan fails |
| Open the endpoint to GitHub runners | One stack, planned in CI | Wide, changing IP ranges; CI would also need an access entry and permission to read release Secrets |
| Argo CD installs the LB controller | No Helm in Terraform for it | Argo CD arrives in Week 3, and itself needs a bootstrap |

**CI access**

| Option | Pros | Cons |
| --- | --- | --- |
| No entry for `nw-gha-apply` (chosen) | No unused standing access; deployments go through Git | CI cannot inspect or repair the cluster |
| Entry with cluster admin | CI could run `kubectl` or Helm | Standing admin that nothing in the delivery design uses |

**KMS key**

| Option | Pros | Cons |
| --- | --- | --- |
| Customer key, per session (chosen for dev) | $1/month prorated; same lifecycle as the cluster | One key per session waits 7–30 days for deletion |
| Customer key, persistent (chosen for prod) | Survives a stack rebuild; can be protected separately | $1/month always; a second lifecycle to manage |
| AWS-owned key (the default on newer versions) | Free, nothing to manage; protects raw etcd storage just as well | No control of the key policy or lifecycle; prod's encryption configuration would first run in prod |

## Consequences
- The module can be changed freely while clusters are rebuilt every session, because no live cluster has
  to be migrated. With long-lived production clusters and a platform team this small, reconsider
  the community module.
- Helm changes are reviewed from a local plan summary in the PR, like `envs/*` today (ADR 0040).
- If `envs/dev` is destroyed first, the Helm stack can no longer reach its cluster and its state needs
  manual clean-up. The Makefile must enforce the order.
- No entry removes standing access, not every route. `nw-gha-apply` is an administrator in the
  management account, so it can normally assume `OrganizationAccountAccessRole` in workloads-dev
  and create an entry there. Scoping it down is tracked in #3.
- A customer key adds control of the key policy and lifecycle. It does not stop anyone whose RBAC
  allows reading Secrets, or who can create pods that mount them. RBAC still has to be tight.
- Losing a cluster's key makes the cluster unrecoverable. This is acceptable in dev, where the data is
  disposable, but not in prod.
- **Open for Day 9:** the tenant module is planned in `envs/dev` with Kubernetes objects, which
  meets the same CI limit. ADR 0090 must settle where those objects live.

## In short
The dev cluster will be rebuilt every session. So we decide to create a new customer key for each
session, which is prod parity, and costs less than 1p per session, under our budget. We will use a
persistent key in the production environment because losing the key means losing the cluster. For
the EKS module, we choose to build our own module, where we only build what we use, which avoids the
breaks from major version releases of the community module and the cost of understanding its
defaults. We separate the AWS stack and the Helm stack because the runner can't reach the endpoint,
so a combined plan would fail. CI only plans the AWS side; the cost is no CI plan for Helm changes.
There is no CI entry because CI never applies `envs/dev`; Argo CD pulls from Git at the deployment step.
