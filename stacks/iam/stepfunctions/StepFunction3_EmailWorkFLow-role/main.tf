# Provider

provider "aws" {
  region = var.region
}


# Account-agnostic helpers

data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}


# Module

module "stepfn_email_workflow_role" {
  # generisches Modul (ohne GUID im Ordnernamen)
  source = "../../../modules/iam/stepfunctions3_emailworkflow_role"

  role_name        = var.role_name
  role_path        = var.role_path
  lambda_resources = var.lambda_resources
  tags             = var.tags

  # optional – wenn zentrale Policies vorhanden sind
  create_managed_policies      = var.create_managed_policies
  existing_managed_policy_arns = var.existing_managed_policy_arns
}


# Outputs

output "role_name" {
  value = module.stepfn_email_workflow_role.role_name
}

output "role_arn" {
  value = module.stepfn_email_workflow_role.role_arn
}
