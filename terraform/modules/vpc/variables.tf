variable "name" {
  description = "Name prefix for every resource, in the form nw-<env> (e.g. nw-dev)."
  type        = string

  # The Day 6 verifier will also find leftovers by this prefix, so a free-form name would hide them.
  validation {
    condition     = can(regex("^nw-[a-z]+$", var.name))
    error_message = "name must look like nw-<env>, e.g. nw-dev."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR of the VPC. Must be a /16, e.g. 10.0.0.0/16."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR, e.g. 10.0.0.0/16."
  }

  # The subnet arithmetic in main.tf assumes a /16; any other size silently changes every subnet's size.
  validation {
    condition     = can(regex("^[0-9.]+/16$", var.cidr_block))
    error_message = "cidr_block must be an IPv4 /16."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to use (2 or 3)."
  type        = number
  default     = 3

  # EKS needs subnets in at least two AZs, and eu-west-2 has three.
  validation {
    condition     = contains([2, 3], var.az_count)
    error_message = "az_count must be 2 or 3."
  }
}

# No default: cost against resilience is a choice each environment has to make (ADR 0042).
variable "single_nat_gateway" {
  description = "true for one NAT gateway shared by all AZs (dev), false for one per AZ (prod)."
  type        = bool
  nullable    = false
}

variable "cluster_name" {
  description = "Name of the EKS cluster that will use these subnets (e.g. nw-dev-eks). Karpenter finds its subnets by this value."
  type        = string
}
