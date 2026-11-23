# Apex zone: the registry delegates only the registered name, so every subzone needs this zone
# above it to hold its NS records (ADR 0041).
resource "aws_route53_zone" "parent" {
  #checkov:skip=CKV2_AWS_38:DNSSEC needs a paid us-east-1 KMS key, and a key or DS mistake takes down every name. Revisit in #32
  #checkov:skip=CKV2_AWS_39:Query logging needs a us-east-1 log group and nothing consumes the logs. Revisit in #32
  name    = var.parent_domain
  comment = "Platform parent zone; the registrar's name servers point here (ADR 0041)."

  # A recreated zone gets new name servers, which breaks every environment until the registrar is updated by hand.
  lifecycle {
    prevent_destroy = true
  }
}

# ---------- Dev zone (workloads-dev) ----------

# In the dev account, so ExternalDNS there needs only a same-account permission on one zone (ADR 0041).
resource "aws_route53_zone" "dev" {
  #checkov:skip=CKV2_AWS_38:DNSSEC needs a paid us-east-1 KMS key, and a key or DS mistake takes down every name. Revisit in #32
  #checkov:skip=CKV2_AWS_39:Query logging needs a us-east-1 log group and nothing consumes the logs. Revisit in #32
  provider = aws.dev

  name    = "${var.dev_subdomain}.${var.parent_domain}"
  comment = "Dev zone, delegated from the parent zone in shared-services (ADR 0041)."

  # A recreated zone gets new name servers, so cached delegations would fail until their TTL runs out.
  lifecycle {
    prevent_destroy = true
  }
}

# In the parent zone (default provider): only the parent can tell resolvers which servers answer for dev.
resource "aws_route53_record" "dev_delegation" {
  zone_id = aws_route53_zone.parent.zone_id
  name    = aws_route53_zone.dev.name
  type    = "NS"
  # Same TTL Route 53 gives a zone's own NS record; delegations rarely change.
  ttl     = 172800
  records = aws_route53_zone.dev.name_servers
}

# ---------- Dev wildcard certificate (workloads-dev) ----------

# In the dev account and region, because an ALB can't use a certificate from anywhere else (ADR 0041).
resource "aws_acm_certificate" "dev_wildcard" {
  provider = aws.dev

  domain_name       = "*.${aws_route53_zone.dev.name}"
  validation_method = "DNS"

  # A listener must always have a certificate, so the new one has to exist before the old one goes.
  lifecycle {
    create_before_destroy = true
  }
}

# Kept after issuance, because ACM looks these records up again at every automatic renewal.
resource "aws_route53_record" "dev_cert_validation" {
  provider = aws.dev

  # Keyed by domain name, which is known at plan time; the record values are not.
  for_each = {
    for option in aws_acm_certificate.dev_wildcard.domain_validation_options : option.domain_name => option
  }

  zone_id = aws_route53_zone.dev.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 300
  records = [each.value.resource_record_value]

  # A replacement certificate reuses the same validation name, which would otherwise clash with the existing record.
  allow_overwrite = true
}

# Creates nothing in AWS: it waits for ISSUED, so a successful apply means the certificate is usable.
resource "aws_acm_certificate_validation" "dev_wildcard" {
  provider = aws.dev

  certificate_arn         = aws_acm_certificate.dev_wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.dev_cert_validation : record.fqdn]

  # ACM checks public DNS, and nothing above references the delegation, so Terraform can't infer this order.
  depends_on = [aws_route53_record.dev_delegation]
}
