terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Falls dein modules/billing-conductor intern awscc_* Ressourcen nutzt:
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 0.75"
    }
  }
}

provider "aws" {
  region = var.region
}

# Nur nötig, wenn das Module awscc verwendet:
provider "awscc" {
  region = var.region
}

module "billing" {
  source = "../../modules/billing-conductor"

  # Wenn dein Modul awscc nutzt, ist das die robuste Variante:
  providers = {
    aws   = aws
    awscc = awscc
  }

  cost_allocation_tag_key = var.cost_allocation_tag_key

  pricing_plan_name = var.pricing_plan_name
  pricing_rule_name = var.pricing_rule_name
  pricing_rule_type = var.pricing_rule_type
  pricing_rule_pct  = var.pricing_rule_pct

  # Liste der Accounts, die in Billing Groups aufgenommen werden sollen
  billing_accounts = var.billing_accounts

  common_tags = var.tags
}

output "pricing_plan_arn" {
  value = module.billing.pricing_plan_arn
}

output "pricing_rule_arn" {
  value = module.billing.pricing_rule_arn
}

output "billing_group_arns" {
  value = module.billing.billing_group_arns
}
