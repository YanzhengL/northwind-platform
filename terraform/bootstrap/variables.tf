variable "region" {
  description = "AWS region for the state bucket and the default provider region."
  type        = string
  default     = "eu-west-2"
}

# ---------- default_tags ----------

variable "team" {
  description = "Team that owns these resources (default_tags: team)."
  type        = string
}

variable "env" {
  description = "Environment name for these resources, e.g. \"shared\" or \"mgmt\" (default_tags: env)."
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

# ---------- State bucket ----------

variable "bucket_suffix" {
  description = "Suffix that makes the state bucket name globally unique. The bucket is named nw-<suffix>-tfstate. Lowercase letters, digits and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.bucket_suffix)) && length(var.bucket_suffix) <= 49
    error_message = "bucket_suffix must be 1-49 chars of lowercase letters, digits or hyphens, and must not start or end with a hyphen."
  }
}

variable "state_noncurrent_version_days" {
  description = "Days to keep old (noncurrent) versions of state files before they are deleted."
  type        = number
  default     = 90
}

# ---------- GitHub OIDC ----------

variable "github_owner" {
  description = "GitHub user or organisation that owns the repository, exactly as it appears in the URL (case-sensitive)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name without the owner, exactly as it appears in the URL (case-sensitive)."
  type        = string
}

variable "github_apply_branch" {
  description = "Branch whose pushes may assume the apply role."
  type        = string
  default     = "main"
}

variable "github_apply_environment" {
  description = "GitHub Actions environment whose jobs may assume the apply role. Set to null to trust only the branch."
  type        = string
  default     = "production"
  nullable    = true
}
