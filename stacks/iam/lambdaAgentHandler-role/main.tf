data "aws_partition" "current" {}
data "aws_region"     "current" {}
data "aws_caller_identity" "current" {}

# Standard: AWS-managed Policies (portabel in jedem Account).
# Wenn ich kundenverwaltete Policies nutzen will, kann ich sie
# via Variable policy_arns_override übergeben.
locals {
  aws_managed_lambda_policies = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = (
    length(var.policy_arns_override) > 0
    ? var.policy_arns_override
    : local.aws_managed_lambda_policies
  )
}

module "role_lambda_agent_handler" {
  source = "../../../modules/iam/lambdaAgentHandler-role"

  role_name   = var.role_name
  role_path   = "/service-role/"
  policy_arns = local.effective_policy_arns
  tags        = var.tags
}

output "role_name" { value = module.role_lambda_agent_handler.role_name }
output "role_arn"  { value = module.role_lambda_agent_handler.role_arn  }
