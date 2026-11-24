terraform {
  # Same floor as the stacks, so the module never loads under a version they would reject.
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Major only: the calling stack's lock file picks the exact version.
      version = "~> 6.0"
    }
  }
}
