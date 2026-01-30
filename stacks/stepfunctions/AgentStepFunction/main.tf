# stacks/stepfunctions/AgentStepFunction/main.tf


provider "aws" {
  region = var.region
}


# Optional: resolve Lambda ARN by name

data "aws_lambda_function" "lambda_by_name" {
  count         = var.lambda_function_name != "" ? 1 : 0
  function_name = var.lambda_function_name
}


# Optional: resolve IAM Role ARN by name

data "aws_iam_role" "role_by_name" {
  count = var.existing_role_name != "" ? 1 : 0
  name  = var.existing_role_name
}


# Optional: resolve Log Group ARN by name

data "aws_cloudwatch_log_group" "lg_by_name" {
  count = var.existing_log_group_name != "" ? 1 : 0
  name  = var.existing_log_group_name
}


# Module call

module "agent_sfn" {
  source = "../../../modules/stepfunctions/AgentStepFunction"

  state_machine_name = var.state_machine_name
  tags               = var.tags

  # Role: allow ARN or Name (or empty if module creates it)
  existing_role_arn = coalesce(
    nullif(var.existing_role_arn, ""),
    try(data.aws_iam_role.role_by_name[0].arn, null)
  )

  # Lambda: allow ARN or Name (portable)
  lambda6_fn_arn = coalesce(
    nullif(var.lambda6_fn_arn, ""),
    try(data.aws_lambda_function.lambda_by_name[0].arn, null)
  )

  argument_function_name = var.argument_function_name

  enable_logging         = var.enable_logging
  log_level              = var.log_level
  include_execution_data = var.include_execution_data

  # Log Group: allow ARN or Name (only needed if logging enabled)
  existing_log_group_arn = coalesce(
    nullif(var.existing_log_group_arn, ""),
    try(data.aws_cloudwatch_log_group.lg_by_name[0].arn, null)
  )
}


# Outputs

output "state_machine_arn" {
  value = module.agent_sfn.state_machine_arn
}

output "role_arn" {
  value = module.agent_sfn.role_arn
}

output "log_group_arn_used" {
  value = module.agent_sfn.log_group_arn_used
}
