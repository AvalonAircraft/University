# Provider

provider "aws" {
  region = var.region
}


# Account-agnostic helpers

data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}


# Module

module "stepfunctions_agent2_role" {
  # neuer, generischer Modulpfad ohne GUID im Ordnernamen
  source = "../../../modules/iam/stepfunctions_role_agent2"

  role_name        = var.role_name
  role_path        = var.role_path
  lambda_resources = var.lambda_resources
  log_group_arns   = var.log_group_arns
  tags             = var.tags

  # Wahlweise: lokal Policies erzeugen oder zentral verwaltete anhängen
  create_managed_policies      = var.create_managed_policies
  existing_managed_policy_arns = var.existing_managed_policy_arns
}


# Outputs

output "role_name" {
  value = module.stepfunctions_agent2_role.role_name
}

output "role_arn" {
  value = module.stepfunctions_agent2_role.role_arn
}
