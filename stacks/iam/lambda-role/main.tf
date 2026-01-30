provider "aws" {
  region = var.region
}


# Account-agnostic helpers

data "aws_partition" "current" {}
data "aws_region" "current" {}

# Optional: resolve KMS key ARN via alias (portable)
data "aws_kms_key" "by_alias" {
  count  = (var.kms_key_arn == "" && var.kms_key_alias != "") ? 1 : 0
  key_id = var.kms_key_alias
}

# Optional: resolve Lambda ARN by function name (portable)
data "aws_lambda_function" "lambda6" {
  count         = (var.lambda6_arn == "" && var.lambda6_function_name != "") ? 1 : 0
  function_name = var.lambda6_function_name
}

# Optional: resolve Step Functions ARN by name (portable)
data "aws_sfn_state_machine" "stepfn" {
  count = (var.stepfn_arn == "" && var.stepfn_state_machine_name != "") ? 1 : 0
  name  = var.stepfn_state_machine_name
}

locals {
  effective_kms_key_arn = coalesce(
    nullif(var.kms_key_arn, ""),
    try(data.aws_kms_key.by_alias[0].arn, null)
  )

  effective_lambda6_arn = coalesce(
    nullif(var.lambda6_arn, ""),
    try(data.aws_lambda_function.lambda6[0].arn, null)
  )

  effective_stepfn_arn = coalesce(
    nullif(var.stepfn_arn, ""),
    try(data.aws_sfn_state_machine.stepfn[0].arn, null)
  )
}


# Module

module "lambda_role_7zfomm5t" {
  source = "../../../modules/iam/lambda-role"

  role_name = var.role_name
  role_path = var.role_path
  tags      = var.tags

  bucket_name = var.bucket_name
  kms_key_arn = local.effective_kms_key_arn
  lambda6_arn = local.effective_lambda6_arn
  stepfn_arn  = local.effective_stepfn_arn
}


# Outputs

output "role_name" {
  value = module.lambda_role_7zfomm5t.role_name
}

output "role_arn" {
  value = module.lambda_role_7zfomm5t.role_arn
}
