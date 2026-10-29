# terraform/org

AWS Organization guardrails, applied from the management account:

- Imports the existing organization (created by Identity Center on Day 1) and enables SCPs and tag policies
- OUs `Infrastructure` and `Workloads`, and accounts `shared-services`, `workloads-dev`, `workloads-prod` (ADR 0020)
- SCPs: region lock (ADR 0022) and baseline guardrails (ADR 0021), attached per OU via `scp_target_ous`
- Tag policy for `team`, `env`, `service`, `owner` (report-only)
- Organization CloudTrail trail and its log bucket (management account for now, #4)
- The Day 1 £20 budget, imported, plus an 80% forecast alert
- Identity Center group `nw-platform-admins` with `NwAdmin` / `NwReadOnly` in every member account

This stack is applied **by a human** with SSO credentials (`AWS_PROFILE=admin`), not by CI.
State: same bucket as `terraform/bootstrap`, key `org/terraform.tfstate`.

## Usage

```bash
export AWS_PROFILE=admin && aws sso login
cp terraform.tfvars.example terraform.tfvars              # fill in, see comments in the file
cp ../bootstrap/backend.s3.tfbackend .                    # gitignored
terraform init -backend-config=backend.s3.tfbackend
terraform plan
```

What a correct first plan looks like:

| Resource | Expected |
| --- | --- |
| `aws_organizations_organization.this` | **will be imported**, updated in place (policy types, service access). Never "must be replaced". |
| `aws_budgets_budget.monthly` | **will be imported**, updated in place: only the FORECASTED notification is added |
| Accounts | 3 to create. Check every name and email before typing `yes`. |

## Not managed here

- The Identity Center instance and the Day 1 `AdministratorAccess` permission set for the management account (kept by hand as the way back in, ADR 0013).
- GitHub settings.
