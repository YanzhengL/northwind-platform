# Same state bucket as terraform/bootstrap, different key. The bucket name is
# supplied at init time so the account ID stays out of git:
#
#   cp ../bootstrap/backend.s3.tfbackend .
#   terraform init -backend-config=backend.s3.tfbackend
#
terraform {
  backend "s3" {
    key          = "org/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true # S3-native locking (Terraform >= 1.11), no DynamoDB table
  }
}
