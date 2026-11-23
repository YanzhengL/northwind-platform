# Re-exported because `terraform output` only reads root outputs, and the registrar step needs this value.
output "parent_name_servers" {
  description = "Name servers to set at the registrar for the parent domain (ADR 0041)."
  value       = module.dns.parent_name_servers
}

output "dev_zone_id" {
  description = "ID of the dev hosted zone in workloads-dev."
  value       = module.dns.dev_zone_id
}

# Sensitive because the ARN contains the account ID (ADR 0032). Read with `terraform output -raw dev_certificate_arn`.
output "dev_certificate_arn" {
  description = "ARN of the dev wildcard certificate."
  value       = module.dns.dev_certificate_arn
  sensitive   = true
}
