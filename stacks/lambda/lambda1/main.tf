module "lambda1" {
  source = "../../modules/lambda1"

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

  # Env/Tags/Rolle
  env              = var.env
  tags             = var.tags
  role_name_suffix = var.role_name_suffix
}

output "lambda_function_arn" { value = module.lambda1.lambda_function_arn }
output "lambda_role_arn"     { value = module.lambda1.lambda_role_arn }
