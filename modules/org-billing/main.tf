terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.54"
    }
  }
}

############################################
# Inputs
############################################
# Für CE: Cost Allocation Tag aktivieren
variable "cost_allocation_tag_key" { type = string, default = "TenantID" }

# Pricing Plan/Rule
variable "pricing_plan_name" { type = string, default = "Tenant_Default_Plan" }
variable "pricing_rule_name" { type = string, default = "Tenant_Default_0pct" }
variable "pricing_rule_type" { type = string, default = "DISCOUNT" } # DISCOUNT | MARKUP
variable "pricing_rule_pct"  { type = number, default = 0 }          # 0..100

# Abrechnungsgruppen: Tenant ↔ Account-Zuordnung
variable "billing_accounts" {
  description = "Liste der Tenants (Account-IDs müssen existieren)."
  type = list(object({
    tenant_id  = string
    account_id = string
    description = optional(string)
    tags        = optional(map(string))
  }))
  default = []
}

variable "common_tags" { type = map(string), default = {} }

############################################
# Cost Allocation Tag aktivieren
############################################
resource "aws_ce_cost_allocation_tag" "tenantid" {
  tag_key = var.cost_allocation_tag_key
  status  = "Active"
}

############################################
# Billing Conductor
############################################
resource "aws_billingconductor_pricing_plan" "plan" {
  name = var.pricing_plan_name
  tags = var.common_tags
}

resource "aws_billingconductor_pricing_rule" "rule_default" {
  name                = var.pricing_rule_name
  description         = "Standard ${var.pricing_rule_type} ${var.pricing_rule_pct}%"
  scope               = "GLOBAL"
  type                = var.pricing_rule_type
  modifier_percentage = var.pricing_rule_pct
  pricing_plan_arn    = aws_billingconductor_pricing_plan.plan.arn
  tags                = var.common_tags
}

resource "aws_billingconductor_billing_group" "bg" {
  for_each = { for b in var.billing_accounts : b.tenant_id => b }

  name        = "bg-${each.key}"
  description = try(each.value.description, "Billing group for ${each.key}")

  primary_account_id = each.value.account_id

  account_grouping {
    linked_account_ids = [each.value.account_id]
  }

  computation_preference {
    pricing_plan_arn = aws_billingconductor_pricing_plan.plan.arn
  }

  tags = merge(var.common_tags, try(each.value.tags, {}), { TenantID = each.key })
}

############################################
# Outputs
############################################
output "pricing_plan_arn" { value = aws_billingconductor_pricing_plan.plan.arn }
output "pricing_rule_arn" { value = aws_billingconductor_pricing_rule.rule_default.arn }

output "billing_group_arns" {
  description = "Map TenantID -> Billing Group ARN"
  value       = { for k, v in aws_billingconductor_billing_group.bg : k => v.arn }
}
