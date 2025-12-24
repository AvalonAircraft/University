provider "aws" {
  region = var.region
}

module "lambda_role_7zfomm5t" {
  source = "../../../modules/iam/lambda-role"

  role_name   = var.role_name
  role_path   = "/service-role/"
  tags        = var.tags

  bucket_name = var.bucket_name
  kms_key_arn = var.kms_key_arn
  lambda6_arn = var.lambda6_arn
  stepfn_arn  = var.stepfn_arn
}

output "role_name" { value = module.lambda_role_7zfomm5t.role_name }
output "role_arn"  { value = module.lambda_role_7zfomm5t.role_arn }
