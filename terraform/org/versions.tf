terraform {
  # >= 1.11 is required for S3-native state locking (use_lockfile = true),
  # which removes the need for a DynamoDB lock table.
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Allow 6.x minor/patch updates, block the next major.
      # The exact version actually used is recorded in .terraform.lock.hcl (commit it).
      version = "~> 6.0"
    }
  }
}
