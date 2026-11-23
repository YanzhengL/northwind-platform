provider "aws" {
  region = var.region

  # Explicit member-account profile, because the backend uses the management one (ADR 0040).
  profile = var.aws_profile

  # A valid login to the wrong account would otherwise build there; this stops before plan.
  allowed_account_ids = [var.account_id]

  # Set per stack so no resource can miss a mandatory tag (Checkov CKV2_NW_1).
  default_tags {
    tags = {
      team    = var.team
      env     = var.env
      service = var.service
      owner   = var.owner
    }
  }
}
