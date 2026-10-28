# Identity Center was enabled by hand on Day 1. The instance itself can't be
# created by Terraform, so read it.
data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# Grant access to a group, not to users: onboarding someone becomes a group
# membership instead of a new assignment per account.
resource "aws_identitystore_group" "platform_admins" {
  identity_store_id = local.identity_store_id
  display_name      = "nw-platform-admins"
  description       = "Platform team: admin and read-only access to member accounts."
}

data "aws_identitystore_user" "admin" {
  for_each = toset(var.sso_admin_usernames)

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = each.key
    }
  }
}

resource "aws_identitystore_group_membership" "platform_admins" {
  for_each = data.aws_identitystore_user.admin

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.platform_admins.group_id
  member_id         = each.value.user_id
}

# ---------- Permission sets ----------

# New names, so the hand-made Day 1 "AdministratorAccess" set for the management
# account is left alone: it is the way back in if this stack breaks.
locals {
  permission_sets = {
    "NwAdmin" = {
      description      = "Full admin in a member account."
      managed_policy   = "AdministratorAccess"
      session_duration = "PT4H"
    }
    "NwReadOnly" = {
      description      = "Read-only in a member account, for looking around safely."
      managed_policy   = "ReadOnlyAccess"
      session_duration = "PT8H"
    }
  }
}

# Look up AWS-managed policy ARNs instead of hard-coding them.
data "aws_iam_policy" "managed" {
  for_each = local.permission_sets

  name = each.value.managed_policy
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.permission_sets

  instance_arn     = local.sso_instance_arn
  name             = each.key
  description      = each.value.description
  session_duration = each.value.session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.permission_sets

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  managed_policy_arn = data.aws_iam_policy.managed[each.key].arn
}

# ---------- Assignments: every permission set in every member account ----------

locals {
  account_assignments = {
    for pair in setproduct(keys(local.permission_sets), keys(var.accounts)) :
    "${pair[0]}/${pair[1]}" => { permission_set = pair[0], account = pair[1] }
  }
}

resource "aws_ssoadmin_account_assignment" "platform_admins" {
  for_each = local.account_assignments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.platform_admins.group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = aws_organizations_account.this[each.value.account].id

  # The policy must be on the permission set before it is provisioned into the account.
  depends_on = [aws_ssoadmin_managed_policy_attachment.this]
}
