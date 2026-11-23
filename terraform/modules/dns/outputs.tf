output "parent_name_servers" {
  description = "Name servers of the parent zone. Set these at the registrar by hand (ADR 0041)."
  value       = aws_route53_zone.parent.name_servers
}

output "dev_zone_id" {
  description = "ID of the dev hosted zone in workloads-dev (used to scope ExternalDNS)."
  value       = aws_route53_zone.dev.zone_id
}

output "dev_certificate_arn" {
  description = "ARN of the dev wildcard certificate, available only once it is issued."
  # From the validation resource, so consumers can't use the certificate before it is ISSUED.
  value = aws_acm_certificate_validation.dev_wildcard.certificate_arn
  # The ARN contains the account ID (ADR 0032).
  sensitive = true
}
