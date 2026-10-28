output "organization_id" {
  description = "ID of the organization."
  value       = aws_organizations_organization.this.id
}

output "ou_ids" {
  description = "OU IDs keyed by OU name."
  value       = { for name, ou in aws_organizations_organizational_unit.this : name => ou.id }
}

# Sensitive so account IDs don't appear in terminal output, recordings or screenshots.
output "account_ids" {
  description = "Member account IDs keyed by account name. Read with `terraform output -json account_ids`."
  value       = { for name, account in aws_organizations_account.this : name => account.id }
  sensitive   = true
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket that holds the organization CloudTrail logs."
  value       = aws_s3_bucket.cloudtrail.bucket
  sensitive   = true
}

output "permission_set_names" {
  description = "Identity Center permission sets assigned in every member account. Use as sso_role_name in ~/.aws/config."
  value       = keys(aws_ssoadmin_permission_set.this)
}
