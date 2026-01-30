# Provider

provider "aws" {
  region = var.region
}


# Account-agnostic helpers

data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}


# Module

module "stepfunctions_agent_role" {
  # generischer Modulpfad ohne GUID im Verzeichnisnamen
  source = "../../../modules/iam/stepfunctions_role_agent"

  role_name      = var.role_name
  role_path      = var.role_path
  lambda_arns    = var.lambda_arns
  log_group_arns = var.log_group_arns
  tags           = var.tags

  # Schalter: Policies lokal erzeugen oder vorhandene anhängen
  create_managed_policies      = var.create_managed_policies
  existing_managed_policy_arns = var.existing_managed_policy_arns
}


# Outputs

output "role_name" {
  value = module.stepfunctions_agent_role.role_name
}

output "role_arn" {
  value = module.stepfunctions_agent_role.role_arn
}
