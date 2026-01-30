# stacks/org-billing/main.tf


provider "aws" {
  region = var.region
}

module "billing" {
  count  = var.enabled ? 1 : 0
  source = "../../modules/billing-conductor"

  cost_allocation_tag_key = var.cost_allocation_tag_key

  pricing_plan_name = var.pricing_plan_name
  pricing_rule_name = var.pricing_rule_name
  pricing_rule_type = var.pricing_rule_type
  pricing_rule_pct  = var.pricing_rule_pct

  # Hier werden die existierenden Account-IDs der Tenants uebergeben
  billing_accounts = var.billing_accounts

  common_tags = var.tags
}

output "pricing_plan_arn" {
  value = try(module.billing[0].pricing_plan_arn, null)
}

output "pricing_rule_arn" {
  value = try(module.billing[0].pricing_rule_arn, null)
}

output "billing_group_arns" {
  value = try(module.billing[0].billing_group_arns, [])
}
