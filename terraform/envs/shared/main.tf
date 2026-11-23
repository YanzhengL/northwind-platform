# Lives in this long-lived stack, not envs/dev, so `make down` can never delete the zone (ADR 0041).
module "dns" {
  source = "../../modules/dns"

  # Aliased providers are never inherited, so the mapping is explicit.
  providers = {
    aws     = aws
    aws.dev = aws.dev
  }

  parent_domain = var.parent_domain
}
