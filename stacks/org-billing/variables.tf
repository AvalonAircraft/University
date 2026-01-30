# stacks/org-billing/variables.tf


variable "region" {
  type    = string
  default = "us-east-1"
}

# Failsafe-Schalter: Damit Professor den Stack deployen kann, auch wenn Billing Conductor
# im Account nicht nutzbar ist (z.B. kein Management/Payer Account).
variable "enabled" {
  type    = bool
  default = false
}

variable "cost_allocation_tag_key" {
  type    = string
  default = "TenantID"
}

variable "pricing_plan_name" {
  type    = string
  default = "Tenant_Default_Plan"
}

variable "pricing_rule_name" {
  type    = string
  default = "Tenant_Default_0pct"
}

variable "pricing_rule_type" {
  type    = string
  default = "DISCOUNT" # oder "MARKUP"
}

variable "pricing_rule_pct" {
  type    = number
  default = 0

  validation {
    condition     = var.pricing_rule_pct >= 0 && var.pricing_rule_pct <= 100
    error_message = "pricing_rule_pct must be between 0 and 100."
  }
}

variable "billing_accounts" {
  type = list(object({
    tenant_id    = string
    account_id   = string
    description  = optional(string)
    tags         = optional(map(string))
  }))

  default = [
    # Beispiel:
    # { tenant_id = "tenant-avalon", account_id = "369546572824" }
  ]
}

variable "tags" {
  type = map(string)
  default = {
    Project = "MiraeDrive"
    Env     = "Prod"
    Owner   = "Platform"
  }
}
