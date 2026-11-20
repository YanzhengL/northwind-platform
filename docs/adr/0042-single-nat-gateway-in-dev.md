# 0042. Use a single NAT gateway and no interface endpoints in dev

- **Status:** accepted
- **Date:** 2026-11-19

## Context
The dev VPC has public and private subnets in three Availability Zones. EKS nodes run in the
private subnets and need outbound access: container images (ECR and public registries), AWS APIs
(EKS, STS, EC2), and Helm charts and Git for Argo CD later.

Approximate `eu-west-2` list prices (check the AWS pricing page before relying on them):

| Item | Price |
| --- | --- |
| NAT gateway | about $0.05/h, plus about $0.05 per GB processed |
| Public IPv4 address (the NAT gateway's Elastic IP) | $0.005/h |
| Interface VPC endpoint | about $0.01/h **per AZ**, plus about $0.01 per GB |
| S3 gateway endpoint | free |
| Data between AZs | about $0.01 per GB in each direction |

Dev runs for a few hours per session, has no availability target, and must fit a £20/month
budget together with EKS. Prod will have an availability target.

## Decision
- **Dev has one NAT gateway**, in one AZ. All private route tables use it.
- The VPC module takes an input for this, so **prod uses one NAT gateway per AZ** without code
  changes.
- **An S3 gateway endpoint** is attached to the private route tables. It is free, and ECR stores
  image layers in S3, so most image-pull traffic skips the NAT gateway's per-GB charge.
- **No interface endpoints in dev.** Three AZs × several services (ECR API, ECR Docker, STS, EC2,
  CloudWatch Logs) would cost more per hour than the NAT gateway they would offload.

## Alternatives considered
| Option | Pros | Cons |
| --- | --- | --- |
| Single NAT gateway (chosen for dev) | A third of the hourly cost; managed by AWS; same module as prod | If its AZ fails, private subnets in all AZs lose outbound access; cross-AZ data charges for traffic from the other two AZs |
| One NAT gateway per AZ | AWS's recommended high-availability design; no cross-AZ hop; an AZ failure stays in that AZ | Three times the cost, for an environment that is destroyed after every session. This is the prod design |
| NAT instance on a small EC2 instance (for example fck-nat on Graviton) | Common in cost-sensitive teams; often under $5/month | You patch and monitor it, it has instance bandwidth limits, and failover is your job |
| No NAT: private subnets with interface endpoints only | Common in regulated environments; no path to the internet | More expensive than a NAT gateway at 3 AZs; public registries, Helm repositories and GitHub become unreachable without a proxy or mirror |
| Nodes in public subnets with public IPs | Cheapest | Every node is directly addressable from the internet; each public IPv4 address is billed; flagged by Checkov and against least exposure |
| IPv6 with an egress-only internet gateway | No NAT charge for IPv6 traffic | An IPv6 EKS cluster is a bigger design change; NAT is still needed for IPv4-only destinations |

## Consequences
- Network cost in dev is about $0.055/h plus traffic. That is roughly 9p per two-hour session,
  and nothing between sessions, because `make down` deletes the NAT gateway and its Elastic IP.
- An outage in the NAT gateway's AZ cuts outbound access for the whole dev cluster: pulls from
  ECR and public registries fail, so new nodes and new pods can't become ready. Accepted for dev;
  it would make a reasonable incident drill.
- Pods in the other two AZs pay cross-AZ charges to reach the NAT gateway. This is small at dev
  traffic levels.
- Revisit interface endpoints if NAT processing grows. Rough break-even for one service: an
  endpoint across 3 AZs costs about $0.03/h, and saves about $0.04 per GB moved off the NAT
  gateway. So it pays for itself above roughly 0.8 GB/h to that service.
- The teardown check in `make down` must confirm that no NAT gateway or Elastic IP tagged `env=dev`
  is left, because these are the two most expensive things to forget.

## In short
Dev uses a single NAT gateway, a deliberate single point of failure. If the NAT gateway's AZ fails,
every private subnet loses outbound access, so new pods can't pull images. But dev has no
availability target and is torn down after every session, so the impact is a short wait. One NAT
gateway costs a third of three, about 9p a session. Prod uses one per AZ: same VPC module, one
variable.
