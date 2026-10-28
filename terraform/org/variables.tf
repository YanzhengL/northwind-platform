variable "region" {
  description = "The only region workloads may use. Also the provider region and the CloudTrail home region."
  type        = string
  default     = "eu-west-2"
}

# ---------- default_tags ----------

variable "team" {
  description = "Team that owns these resources (default_tags: team)."
  type        = string
}

variable "env" {
  description = "Environment name for these resources, e.g. \"mgmt\" (default_tags: env)."
  type        = string
}

variable "service" {
  description = "Service or project name (default_tags: service)."
  type        = string
}

variable "owner" {
  description = "Person or contact responsible for these resources (default_tags: owner)."
  type        = string
}

# ---------- Organization ----------

variable "organization_id" {
  description = "ID of the existing organization (o-xxxxxxxxxx), created when IAM Identity Center was enabled. Used once to import it."
  type        = string

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "organization_id must look like o-xxxxxxxxxx."
  }
}

variable "org_service_access_principals" {
  description = "Complete list of AWS services with trusted access to the organization. Terraform removes any service not listed, so start from `aws organizations list-aws-service-access-for-organization`."
  type        = list(string)

  # Dropping sso.amazonaws.com would disable Identity Center and lock out every SSO login.
  validation {
    condition     = contains(var.org_service_access_principals, "sso.amazonaws.com")
    error_message = "sso.amazonaws.com must stay in the list, or Identity Center access breaks."
  }

  validation {
    condition     = contains(var.org_service_access_principals, "cloudtrail.amazonaws.com")
    error_message = "cloudtrail.amazonaws.com is required for the organization trail."
  }
}

variable "organizational_units" {
  description = "Names of the OUs created directly under the organization root (ADR 0020)."
  type        = set(string)
  default     = ["Infrastructure", "Workloads"]
}

variable "accounts" {
  description = "Member accounts to create, keyed by account name. `ou` must be one of organizational_units. Check emails carefully: closing an account is slow and limited."
  type = map(object({
    email = string
    ou    = string
  }))

  validation {
    condition     = alltrue([for a in values(var.accounts) : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", a.email))])
    error_message = "Every account needs a valid email address."
  }
}

# ---------- SCPs ----------

variable "scp_target_ous" {
  description = "OUs the SCPs are attached to. Start with [\"Workloads\"], test, then add \"Infrastructure\" (ADR 0021)."
  type        = set(string)
  default     = ["Workloads"]
}

variable "region_lock_exempt_actions" {
  description = "Actions for global services that the region lock must not deny (NotAction). Add an entry only after a real failure, and record it in ADR 0022."
  type        = list(string)
  default = [
    "iam:*",
    "organizations:*",
    "sts:*",
    "route53:*",
    "cloudfront:*",
    "support:*",
    "budgets:*",
  ]
}

# ---------- CloudTrail ----------

variable "bucket_suffix" {
  description = "Suffix that makes the CloudTrail log bucket name globally unique. The bucket is named nw-<suffix>-cloudtrail. Use the same suffix as the state bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.bucket_suffix)) && length(var.bucket_suffix) <= 46
    error_message = "bucket_suffix must be 1-46 chars of lowercase letters, digits or hyphens, and must not start or end with a hyphen."
  }
}

variable "cloudtrail_log_retention_days" {
  description = "Days to keep CloudTrail log files before they expire."
  type        = number
  default     = 365
}

# ---------- Budget (imported from the Day 1 console setup) ----------

variable "budget_name" {
  description = "Exact name of the budget created by hand on Day 1 (`aws budgets describe-budgets`)."
  type        = string
}

variable "budget_limit_amount" {
  description = "Monthly limit, exactly as describe-budgets returns it (e.g. \"20.0\")."
  type        = string
}

variable "budget_limit_unit" {
  description = "Currency of the limit, exactly as describe-budgets returns it (e.g. \"USD\")."
  type        = string
}

variable "budget_actual_threshold_percent" {
  description = "Threshold of the existing ACTUAL-spend alert, as set on Day 1 (`aws budgets describe-notifications-for-budget`)."
  type        = number
  default     = 100
}

variable "budget_alert_emails" {
  description = "Email addresses that receive budget alerts."
  type        = list(string)
}

# ---------- Identity Center ----------

variable "sso_admin_usernames" {
  description = "Existing Identity Center usernames to add to the nw-platform-admins group."
  type        = list(string)
}
