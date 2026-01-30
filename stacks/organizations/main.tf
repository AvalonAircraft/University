########################################
# stacks/organizations/variables.tf
########################################

variable "region" {
  type    = string
  default = "us-east-1"
}

# Failsafe: Organizations geht nur im AWS Organizations MANAGEMENT (payer) Account.
# Default = false, damit Uni/Professor-Deploy nicht abbricht.
variable "enabled" {
  type    = bool
  default = false
}

variable "ou_core_name" {
  type    = string
  default = "Core"
}

variable "ou_tenants_name" {
  type    = string
  default = "Tenants"
}

variable "tenant_id_pattern" {
  description = "Pattern for tenant ids (used for tagging / account naming rules)"
  type        = string
  default     = "tenant*"
}

variable "tenants" {
  description = "List of tenants to create as accounts (ONLY works in management account)."
  type = list(object({
    tenant_id      = string
    email          = string
    account_name   = optional(string)
    ou             = optional(string) # "core" | "tenants"
    tags           = optional(map(string))
  }))
  default = []
}

variable "tags" {
  type = map(string)
  default = {
    Project = "MiraeDrive"
    Env     = "Prod"
    Owner   = "Platform"
  }
}
