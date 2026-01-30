# Optional: existing IAM role by NAME -> ARN

data "aws_iam_role" "existing" {
  count = trim(var.existing_role_name) != "" ? 1 : 0
  name  = var.existing_role_name
}


# Optional: existing LogGroup by NAME -> ARN

data "aws_cloudwatch_log_group" "existing" {
  count = trim(var.existing_log_group_name) != "" ? 1 : 0
  name  = var.existing_log_group_name
}


# Resolve Lambda ARNs by name (portable)

data "aws_lambda_function" "resolve_tenant" {
  count         = (trim(var.lambda_resolve_tenant_arn) == "" && trim(var.lambda_resolve_tenant_name) != "") ? 1 : 0
  function_name = var.lambda_resolve_tenant_name
}

data "aws_lambda_function" "move_email" {
  count         = (trim(var.lambda_move_email_arn) == "" && trim(var.lambda_move_email_name) != "") ? 1 : 0
  function_name = var.lambda_move_email_name
}

data "aws_lambda_function" "forward_vpc" {
  count         = (trim(var.lambda_forward_vpc_arn) == "" && trim(var.lambda_forward_vpc_name) != "") ? 1 : 0
  function_name = var.lambda_forward_vpc_name
}


# Final resolved ARNs (coalesce)

locals {
  resolved_existing_role_arn = coalesce(
    nullif(var.existing_role_arn, ""),
    try(data.aws_iam_role.existing[0].arn, null)
  )

  resolved_existing_log_group_arn = coalesce(
    nullif(var.existing_log_group_arn, ""),
    try(data.aws_cloudwatch_log_group.existing[0].arn, null)
  )

  resolved_lambda_resolve_tenant_arn = coalesce(
    nullif(var.lambda_resolve_tenant_arn, ""),
    try(data.aws_lambda_function.resolve_tenant[0].arn, null)
  )

  resolved_lambda_move_email_arn = coalesce(
    nullif(var.lambda_move_email_arn, ""),
    try(data.aws_lambda_function.move_email[0].arn, null)
  )

  resolved_lambda_forward_vpc_arn = coalesce(
    nullif(var.lambda_forward_vpc_arn, ""),
    try(data.aws_lambda_function.forward_vpc[0].arn, null)
  )
}


# Module

module "stepfunction3" {
  source = "../../../modules/stepfunctions/StepFunction3_EmailWorkFLow"

  state_machine_name = var.state_machine_name
  tags               = var.tags

  # existing role optional (empty => module creates)
  existing_role_arn = local.resolved_existing_role_arn

  # Lambda targets (resolved)
  lambda_resolve_tenant_arn = local.resolved_lambda_resolve_tenant_arn
  lambda_move_email_arn     = local.resolved_lambda_move_email_arn
  lambda_forward_vpc_arn    = local.resolved_lambda_forward_vpc_arn

  # Logging (either existing log group OR create one)
  enable_logging         = var.enable_logging
  existing_log_group_arn = local.resolved_existing_log_group_arn
  create_log_group       = var.create_log_group
  log_group_name         = var.log_group_name
  log_retention_days     = var.log_retention_days
  log_level              = var.log_level
  include_execution_data = var.include_execution_data
}


# Outputs

output "state_machine_arn" {
  value = module.stepfunction3.state_machine_arn
}

output "role_arn" {
  value = module.stepfunction3.role_arn
}
