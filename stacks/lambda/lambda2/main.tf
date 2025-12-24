module "lambda2" {
  source = "../../modules/lambda2"

  function_name = var.function_name
  runtime       = var.runtime
  handler       = var.handler

  # Code
  use_archive = var.use_archive
  source_file = var.source_file
  filename    = var.filename

  # Limits / Settings
  memory_size            = var.memory_size
  ephemeral_storage_size = var.ephemeral_storage_size
  timeout                = var.timeout
  description            = var.description
  log_retention_days     = var.log_retention_days

  # Bedrock (IAM strikt nur für dieses Modell)
  bedrock_model_id = var.bedrock_model_id

  # VPC (optional)
  attach_vpc_access  = var.attach_vpc_access
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Env/Tags/Rolle
  env              = var.env
  tags             = var.tags
  role_name_suffix = var.role_name_suffix
}

output "lambda_function_arn" { value = module.lambda2.lambda_function_arn }
output "lambda_role_arn"     { value = module.lambda2.lambda_role_arn }
