variable "region" {
  description = "Provider region. eu-west-2 is the only region the SCPs allow (ADR 0022)."
  type        = string
  default     = "eu-west-2"
}

# ---------- default_tags ----------

variable "team" {
  description = "Team that owns these resources (default_tags: team)."
  type        = string
}

variable "env" {
  description = "Environment name for these resources: one of mgmt, shared, dev, prod (default_tags: env)."
  type        = string
  # Checkov CKV2_NW_1 only proves the env tag exists; this pins its value to the four account names (ADR 0040).
  validation {
    condition     = contains(["mgmt", "shared", "dev", "prod"], var.env)
    error_message = "env must be one of: mgmt, shared, dev, prod."
  }
}

variable "service" {
  description = "Service or project name (default_tags: service)."
  type        = string
}

variable "owner" {
  description = "Person or contact responsible for these resources (default_tags: owner)."
  type        = string
}

# ---------- Target account (ADR 0040) ----------

variable "aws_profile" {
  description = "IAM Identity Center profile the provider uses to build in the shared account (e.g. nw-shared). The backend uses the management profile from backend.s3.tfbackend instead."
  type        = string
}

variable "account_id" {
  description = "ID of the shared account. The provider refuses any other account (allowed_account_ids), so a wrong profile fails before plan."
  type        = string
  # Account IDs identify the org, so keep them out of plan output in public PRs (ADR 0032).
  sensitive = true
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}
