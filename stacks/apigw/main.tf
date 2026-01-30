provider "aws" {
  region = var.region
}


# Resolve Lambda ARNs by name

data "aws_lambda_function" "aurora" {
  function_name = var.lambda_aurora_function_name
}

data "aws_lambda_function" "agent" {
  function_name = var.lambda_agent_function_name
}


# API Gateway module

module "apigw" {
  source          = "../../modules/apigw_rest"
  api_name        = var.api_name
  api_description = var.api_description

  lambda_arn_aurora = data.aws_lambda_function.aurora.arn
  lambda_arn_agent  = data.aws_lambda_function.agent.arn

  s3_bucket_name = var.s3_bucket_name
}


# Outputs

output "api_id" {
  value = module.apigw.api_id
}

output "invoke_url" {
  value = module.apigw.invoke_url
}
