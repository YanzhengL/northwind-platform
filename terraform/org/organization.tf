# The organization already exists: enabling Identity Center on Day 1 created it.
# Import it instead of creating a new one. The plan must say "will be imported"
# and show only in-place changes, never "must be replaced".
import {
  to = aws_organizations_organization.this
  id = var.organization_id
}

resource "aws_organizations_organization" "this" {
  feature_set                   = "ALL"
  aws_service_access_principals = var.org_service_access_principals

  # Enabling SCPs makes AWS attach FullAWSAccess everywhere, which the
  # deny-list guardrails then subtract from (ADR 0021).
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]

  # Destroying this resource would delete the whole organization.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "this" {
  for_each = var.organizational_units

  name      = each.key
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name      = each.key
  email     = each.value.email
  parent_id = aws_organizations_organizational_unit.this[each.value.ou].id

  # Organizations creates this role in the new account so the management
  # account can get in before Identity Center access exists.
  role_name = "OrganizationAccountAccessRole"

  lifecycle {
    # Closing an account takes 90 days and is quota-limited, so removing one is a deliberate edit.
    prevent_destroy = true
    # AWS doesn't return role_name after creation; without this every plan would try to replace the account.
    ignore_changes = [role_name]
  }
}
