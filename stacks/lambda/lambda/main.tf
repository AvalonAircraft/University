module "lambda" {
  source = "../../modules/lambda"

  function_name = var.function_name
  runtime       = var.runtime
  handler       = var.handler

  use_archive = var.use_archive
  source_file = var.source_file
  filename    = var.filename

  memory_size            = var.memory_size
  ephemeral_storage_size = var.ephemeral_storage_size
  timeout                = var.timeout
  log_retention_days     = var.log_retention_days

  #Modul erwartet Alias & SFN-Name
  kms_key_alias      = var.kms_key_alias
  state_machine_name = var.state_machine_name

  role_name_suffix = var.role_name_suffix
  tags             = var.tags
}

output "lambda_function_arn" { value = module.lambda.lambda_function_arn }
output "lambda_role_arn"     { value = module.lambda.lambda_role_arn }
