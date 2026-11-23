variable "parent_domain" {
  description = "Registered domain whose apex zone this module hosts, without a trailing dot (e.g. example.com)."
  type        = string

  # Route 53 would create a zone for any name; a typo only shows up later as a delegation that never resolves.
  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.parent_domain))
    error_message = "parent_domain must be a lowercase domain name with no trailing dot, e.g. example.com."
  }
}

variable "dev_subdomain" {
  description = "Label of the dev zone under parent_domain. The dev zone is <dev_subdomain>.<parent_domain>."
  type        = string
  default     = "nw-dev"

  # One label only: the wildcard certificate and the hostname scheme assume it (ADR 0041).
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.dev_subdomain))
    error_message = "dev_subdomain must be a single lowercase DNS label, e.g. nw-dev."
  }
}
