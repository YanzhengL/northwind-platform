provider "aws" {
  region = var.region

  # Applied to every taggable resource this configuration creates.
  default_tags {
    tags = {
      team    = var.team
      env     = var.env
      service = var.service
      owner   = var.owner
    }
  }
}
