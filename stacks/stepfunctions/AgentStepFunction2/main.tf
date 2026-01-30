# Optional lookups (portable): Role by name

data "aws_iam_role" "existing" {
  count = var.existing_role_name != "" ? 1 : 0
  name  = var.existing_role_name
}


# Optional lookups (portable): Log group by name

data "aws_cloudwatch_log_group" "existing" {
  count = var.existing_log_group_name != "" ? 1 : 0
  name  = var.existing_log_group_name
}


# Optional lookups (portable): Lambdas by name

data "aws_lambda_function" "lambda1" {
  count         = var.lambda1_fn_name != "" ? 1 : 0
  function_name = var.lambda1_fn_name
}

data "aws_lambda_function" "lambda2" {
  count         = var.lambda2_fn_name != "" ? 1 : 0
  function_name = var.lambda2_fn_name
}

data "aws_lambda_function" "lambda3" {
  count         = var.lambda3_fn_name != "" ? 1 : 0
  function_name = var.lambda3_fn_name
}

data "aws_lambda_function" "lambda4" {
  count         = var.lambda4_fn_name != "" ? 1 : 0
  function_name = var.lambda4_fn_name
}

data "aws_lambda_function" "lambda5" {
  count         = var.lambda5_fn_name != "" ? 1 : 0
  function_name = var.lambda5_fn_name
}

data "aws_lambda_function" "lambda6" {
  count         = var.lambda6_fn_name != "" ? 1 : 0
  function_name = var.lambda6_fn_name
}


# Resolved ARNs (ARN wins, else lookup-by-name)

locals {
  resolved_role_arn = coalesce(
    nullif(var.existing_role_arn, ""),
    try(data.aws_iam_role.existing[0].arn, null)
  )

  resolved_log_group_arn = coalesce(
    nullif(var.existing_log_group_arn, ""),
    try(data.aws_cloudwatch_log_group.existing[0].arn, null)
  )

  lambda1_arn = coalesce(nullif(var.lambda1_fn_arn, ""), try(data.aws_lambda_function.lambda1[0].arn, null))
  lambda2_arn = coalesce(nullif(var.lambda2_fn_arn, ""), try(data.aws_lambda_function.lambda2[0].arn, null))
  lambda3_arn = coalesce(nullif(var.lambda3_fn_arn, ""), try(data.aws_lambda_function.lambda3[0].arn, null))
  lambda4_arn = coalesce(nullif(var.lambda4_fn_arn, ""), try(data.aws_lambda_function.lambda4[0].arn, null))
  lambda5_arn = coalesce(nullif(var.lambda5_fn_arn, ""), try(data.aws_lambda_function.lambda5[0].arn, null))
  lambda6_arn = coalesce(nullif(var.lambda6_fn_arn, ""), try(data.aws_lambda_function.lambda6[0].arn, null))
}


# Module

module "agent_sfn2" {
  source = "../../../modules/stepfunctions/AgentStepFunction2"

  state_machine_name = var.state_machine_name
  tags               = var.tags

  # IAM role (optional): ARN or name -> resolved ARN
  existing_role_arn = local.resolved_role_arn

  # Lambdas: pass ARNs (resolved)
  lambda1_fn = local.lambda1_arn
  lambda2_fn = local.lambda2_arn
  lambda3_fn = local.lambda3_arn
  lambda4_fn = local.lambda4_arn
  lambda5_fn = local.lambda5_arn
  lambda6_fn = local.lambda6_arn

  # Logging
  enable_logging         = var.enable_logging
  log_level              = var.log_level
  include_execution_data = var.include_execution_data

  # Either existing log group (resolved)...
  existing_log_group_arn = local.resolved_log_group_arn

  # ...or create one:
  create_log_group   = var.create_log_group
  log_group_name     = var.log_group_name
  log_retention_days = var.log_retention_days
}


# Outputs

output "state_machine_arn"  { value = module.agent_sfn2.state_machine_arn }
output "role_arn"           { value = module.agent_sfn2.role_arn }
output "log_group_arn_used" { value = module.agent_sfn2.log_group_arn_used }
