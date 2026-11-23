# Same state bucket as terraform/org, different key. State lives in the management account,
# so the backend reads it with the management profile, while the provider builds in the
# dev account (ADR 0040). Bucket name and profile are supplied at init time, so the
# account ID stays out of git:
#
#   cp ../../org/backend.s3.tfbackend .
#   echo 'profile = "nw-management"' >> backend.s3.tfbackend
#   terraform init -backend-config=backend.s3.tfbackend
#
terraform {
  backend "s3" {
    key          = "envs/dev/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true # S3-native locking (Terraform >= 1.11), no DynamoDB table
  }
}
