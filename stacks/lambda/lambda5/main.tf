module "lambda5" {
  source = "../../modules/lambda5"

  # Basics
  function_name = var.function_name
  runtime       = var.runtime
  handler       = var.handler
  description   = var.description

  # Code
  use_archive = var.use_archive
  source_file = var.source_file
  filename    = var.filename

  # Limits
  memory_size            = var.memory_size
  ephemeral_storage_size = var.ephemeral_storage_size
  timeout                = var.timeout

  # ENV/Tags
  env  = merge({ DEFAULT_CLIENTS = var.default_clients, STRICT_MODE = var.strict_mode }, var.extra_env)
  tags = var.tags

  # IAM Rolle (bestehend)
  existing_role_name = var.existing_role_name
}

output "lambda_function_arn" { value = module.lambda5.lambda_function_arn }
output "lambda_role_arn"     { value = module.lambda5.lambda_role_arn }
