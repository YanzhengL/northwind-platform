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

# Second account: the dev zone and certificate belong in workloads-dev (ADR 0041).
provider "aws" {
  alias  = "dev"
  region = var.region

  profile = var.dev_aws_profile

  # Guards the alias separately, because the default provider's check doesn't cover it.
  allowed_account_ids = [var.dev_account_id]

  # An alias doesn't inherit default_tags, so it needs its own (Checkov CKV2_NW_1).
  # env stays "shared", so teardown checks that filter on env=dev never count these long-lived resources.
  default_tags {
    tags = {
      team    = var.team
      env     = var.env
      service = var.service
      owner   = var.owner
    }
  }
}
