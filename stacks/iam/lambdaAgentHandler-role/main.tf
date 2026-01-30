# Provider

provider "aws" {
  region = var.region
}


# Data Sources

data "aws_partition" "current" {}


# Locals: AWS-managed default policies (portable)

locals {
  aws_managed_lambda_policies = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = length(var.policy_arns_override) > 0
    ? var.policy_arns_override
    : local.aws_managed_lambda_policies
}


# Module

module "role_lambda_agent_handler" {
  source = "../../../modules/iam/lambdaAgentHandler-role"

  role_name   = var.role_name
  role_path   = var.role_path
  policy_arns = local.effective_policy_arns
  tags        = var.tags
}


# Outputs

output "role_name" {
  value = module.role_lambda_agent_handler.role_name
}

output "role_arn" {
  value = module.role_lambda_agent_handler.role_arn
}
