provider "aws" {
  region = var.region
}

module "billing" {
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

output "pricing_plan_arn"   { value = module.billing.pricing_plan_arn }
output "pricing_rule_arn"   { value = module.billing.pricing_rule_arn }
output "billing_group_arns" { value = module.billing.billing_group_arns }
