output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state. Use it as `bucket` in every backend \"s3\" block."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_region" {
  description = "Region of the state bucket. Use it as `region` in backend \"s3\" blocks."
  value       = var.region
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider in this account."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "gha_plan_role_arn" {
  description = "ARN of nw-gha-plan. Use as role-to-assume in the pull_request workflow."
  value       = aws_iam_role.gha_plan.arn
}

output "gha_apply_role_arn" {
  description = "ARN of nw-gha-apply. Use as role-to-assume in the main / environment workflow."
  value       = aws_iam_role.gha_apply.arn
}
