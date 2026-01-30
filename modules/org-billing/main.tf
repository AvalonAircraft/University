# Module: Billing-Conductor-Tenants


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.54"
    }
  }
}


# Inputs


variable "cost_allocation_tag_key" { 
  type        = string 
  default     = "TenantID" 
  description = "Tag-Key für Cost Explorer Allocation."
}

variable "pricing_plan_name" { type = string, default = "MiraeDrive_Default_Plan" }
variable "pricing_rule_name" { type = string, default = "Global_Discount_Rule" }
variable "pricing_rule_type" { type = string, default = "DISCOUNT" } # DISCOUNT | MARKUP
variable "pricing_rule_pct"  { type = number, default = 0 }

variable "billing_accounts" {
  description = "Liste der Tenants (Account-IDs müssen Teil der AWS Organization sein)."
  type = list(object({
    tenant_id   = string
    account_id  = string
    description = optional(string)
    tags        = optional(map(string))
  }))
  default = []
}

variable "common_tags" { type = map(string), default = {} }


# 1. Cost Allocation Tag


# Aktiviert den Tag im Cost Explorer, damit Kosten nach TenantID gruppiert werden können
resource "aws_ce_cost_allocation_tag" "tenantid" {
  tag_key = var.cost_allocation_tag_key
  status  = "Active"
}


# 2. Pricing Plan & Rules


# Der Plan definiert, wie die Preise für die Abrechnungsgruppen berechnet werden
resource "aws_billingconductor_pricing_plan" "plan" {
  name = var.pricing_plan_name
  tags = var.common_tags
}

# Die Regel bestimmt den globalen Aufschlag/Rabatt (z.B. für Reseller-Szenarien)
resource "aws_billingconductor_pricing_rule" "rule_default" {
  name                = var.pricing_rule_name
  description         = "Standard ${var.pricing_rule_type} ${var.pricing_rule_pct}%"
  scope               = "GLOBAL"
  type                = var.pricing_rule_type
  modifier_percentage = var.pricing_rule_pct
  pricing_plan_arn    = aws_billingconductor_pricing_plan.plan.arn
  tags                = var.common_tags
}


# 3. Billing Groups (Per Tenant)


# Erzeugt für jeden Tenant eine eigene isolierte Abrechnungsansicht
resource "aws_billingconductor_billing_group" "bg" {
  for_each = { for b in var.billing_accounts : b.tenant_id => b }

  name        = "bg-${each.key}"
  description = coalesce(each.value.description, "Billing group for Tenant ${each.key}")

  primary_account_id = each.value.account_id

  account_grouping {
    linked_account_ids = [each.value.account_id]
  }

  computation_preference {
    pricing_plan_arn = aws_billingconductor_pricing_plan.plan.arn
  }

  tags = merge(
    var.common_tags, 
    try(each.value.tags, {}), 
    { (var.cost_allocation_tag_key) = each.key }
  )
}


# Outputs


output "pricing_plan_arn" { value = aws_billingconductor_pricing_plan.plan.arn }

output "billing_group_arns" {
  description = "Map: TenantID -> Billing Group ARN"
  value       = { for k, v in aws_billingconductor_billing_group.bg : k => v.arn }
}
