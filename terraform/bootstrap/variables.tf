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

variable "github_owner_id" {
  description = "Numeric ID of the repository owner (gh api users/<owner> --jq .id). Part of GitHub's immutable OIDC sub claim."
  type        = string
  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must be the numeric GitHub ID."
  }
}

variable "github_repo_id" {
  description = "Numeric ID of the repository (gh api repos/<owner>/<repo> --jq .id). Part of GitHub's immutable OIDC sub claim."
  type        = string
  validation {
    condition     = can(regex("^[0-9]+$", var.github_repo_id))
    error_message = "github_repo_id must be the numeric GitHub ID."
  }
}

variable "github_apply_environment" {
  description = "GitHub Actions environment whose jobs may assume the apply role. Its protection rules (required reviewer, deployment branch main) are the approval gate (ADR 0012)."
  type        = string
  default     = "terraform-apply"
  # Required: the environment subject is the only apply trust, so null or "" would leave a policy nothing can match.
  nullable = false
  validation {
    condition     = length(trimspace(var.github_apply_environment)) > 0
    error_message = "github_apply_environment must be a non-empty GitHub environment name."
  }
}
