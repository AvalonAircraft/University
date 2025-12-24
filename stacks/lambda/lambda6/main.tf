module "lambda6" {
  source = "../../modules/lambda/lambda6"

  function_name = var.function_name
  runtime       = var.runtime
  handler       = var.handler

  # Code
  use_archive = var.use_archive
  source_file = var.source_file
  filename    = var.filename

  # Limits
  memory_size            = var.memory_size
  ephemeral_storage_size = var.ephemeral_storage_size
  timeout                = var.timeout

  # Env & Tags
  env  = var.env
  tags = var.tags

  # VPC (vom Network-/SG-Stack durchreichen)
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  attach_vpc_access  = var.attach_vpc_access

  # Capabilities
  kms_key_alias        = var.kms_key_alias
  layer_arns           = var.layer_arns
  s3_read_bucket_names = var.s3_read_bucket_names
  add_elbv2_describe   = var.add_elbv2_describe

  # Invoke permissions
  api_gateway_ids               = var.api_gateway_ids
  allow_invoke_from_lambda_arns = var.allow_invoke_from_lambda_arns
}

output "lambda_function_arn" { value = module.lambda6.lambda_function_arn }
output "lambda_role_arn"     { value = module.lambda6.lambda_role_arn }
