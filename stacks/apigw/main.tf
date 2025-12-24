# stacks/apigw/main.tf
module "apigw" {
  source            = "../../modules/apigw_rest"
  api_name          = var.api_name
  api_description   = var.api_description
  lambda_arn_aurora = var.lambda_arn_aurora
  lambda_arn_agent  = var.lambda_arn_agent
  s3_bucket_name    = var.s3_bucket_name
}

output "api_id"     { value = module.apigw.api_id }
output "invoke_url" { value = module.apigw.invoke_url }
