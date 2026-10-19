# State for this stack lives in the bucket it creates. The bucket name is not
# set here (it contains the account ID); supply it at init time:
#
#   terraform init -backend-config=backend.s3.tfbackend
#
# First-ever run (bucket doesn't exist yet): see README.md "Usage".
#
terraform {
  backend "s3" {
    # bucket       = "" bucket is supplied at init time, so this file can be checked in without secrets
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true # S3-native locking (Terraform >= 1.11), no DynamoDB table
  }
}
