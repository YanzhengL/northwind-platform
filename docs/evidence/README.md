# Evidence

Screenshots and recordings captured from real runs. They back up the claims in the README and postmortems.

**Naming:** `YYYY-MM-DD-<what>.png`, e.g. `2026-11-20-drill1-slack-alert.png`.

**Before committing:** blur AWS account IDs, emails, webhook URLs and anything secret.

| File | Shows | Used in |
| --- | --- | --- |
| [2026-10-29-scp-region-deny.png](2026-10-29-scp-region-deny.png) | `s3 mb` in us-east-1 from workloads-dev denied by the region-lock SCP; IAM (exempt) still works | [ADR 0021](../adr/0021-deny-list-scps.md) |
| [2026-10-29-cloudtrail-scp-deny-event.png](2026-10-29-cloudtrail-scp-deny-event.png) | The denied CreateBucket recorded by the org trail in S3 | [ADR 0021](../adr/0021-deny-list-scps.md) |
| [2026-10-31-apply-environment.png](2026-10-31-apply-environment.png) | `terraform-apply` environment: required reviewer, deployments limited to `main` | [ADR 0012](../adr/0012-gha-apply-trust.md) |
| [2026-11-09-protect-main-push-rejected.png](2026-11-09-protect-main-push-rejected.png) | Direct `git push origin main` rejected by the `protect-main` ruleset (GH013: PR required, `ci-ok` check expected) | [ADR 0035](../adr/0035-branch-protection-rulesets.md) |
| [2026-11-10-pr-plan-infracost.png](2026-11-10-pr-plan-infracost.png) | PR comments: Infracost report (default tag policy still failing) and the redacted `org` plan, addresses and actions only | [ADR 0032](../adr/0032-public-repo-plan-hygiene.md), [ADR 0033](../adr/0033-iac-scanning-and-cost-gates.md) |
| [2026-11-11-pr-checkov-finding.png](2026-11-11-pr-checkov-finding.png) | A deliberate open-SSH security group failing Checkov, shown as code scanning annotations on the PR | [ADR 0033](../adr/0033-iac-scanning-and-cost-gates.md) |
| [2026-11-16-infracost-tags-pass.png](2026-11-16-infracost-tags-pass.png) | Infracost comment passing after the tag policy was set to `team`, `env`, `service`, `owner` | [ADR 0037](../adr/0037-mandatory-tags-on-prs.md) |
| [2026-11-16-apply-oidc-role.png](2026-11-16-apply-oidc-role.png) | Apply job log printing `assumed-role/nw-gha-apply/GitHubActions`: OIDC credentials, no account ID | [ADR 0012](../adr/0012-gha-apply-trust.md) |
| [2026-11-23-acm-cert-issued.png](2026-11-23-acm-cert-issued.png) | The dev wildcard certificate `Issued` in ACM, validated by DNS in the delegated dev zone | [ADR 0041](../adr/0041-delegated-dns-subzone-per-account.md) |
| [2026-11-24-vpc-resource-map.png](2026-11-24-vpc-resource-map.png) | Dev VPC resource map: six subnets in three AZs, one private route table per AZ, one NAT gateway, the IGW and the S3 endpoint | [ADR 0042](../adr/0042-single-nat-gateway-in-dev.md), [README](../../README.md) |
| [2026-11-24-vpc-private-routes.png](2026-11-24-vpc-private-routes.png) | The eu-west-2b private route table: default route to the NAT gateway, S3 prefix list to the gateway endpoint | [ADR 0042](../adr/0042-single-nat-gateway-in-dev.md) |
| [2026-11-24-make-down-clean.png](2026-11-24-make-down-clean.png) | `make down` destroying all 26 network resources, with no NAT gateway or Elastic IP left | [ADR 0042](../adr/0042-single-nat-gateway-in-dev.md), [README](../../README.md) |
