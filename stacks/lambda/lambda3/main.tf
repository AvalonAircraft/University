module "lambda3" {
  source = "../../modules/lambda3"

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

  # ENV (wie in der Konsole + sinnvolle Defaults)
  env = merge(
    {
      OUTPUT_BUCKET         = var.output_bucket
      CF_DOMAIN             = var.cf_domain
      FOLDER_NAME           = var.folder_name                # für Kompatibilität mit Konsole
      PDF_TENANT_SUBFOLDER  = var.folder_name                # vom Code genutzt
      ROOT_PREFIX           = var.root_prefix
      KMS_KEY_ID            = var.kms_key_id
      KI_RESULTS_ROLLING_LIMIT = tostring(var.ki_results_rolling_limit)
      PRESIGN_EXPIRES       = tostring(var.presign_expires)
      USE_PRESIGNED         = var.use_presigned ? "1" : "0"
    },
    var.extra_env
  )

  tags = var.tags

  # IAM Rolle (bestehend, wie in der Konsole)
  existing_role_name = var.existing_role_name

  # API Gateway Trigger
  api_gateway_ids   = var.api_gateway_ids
  api_resource_path = var.api_resource_path
  api_methods       = var.api_methods
}

output "lambda_function_arn" { value = module.lambda3.lambda_function_arn }
output "lambda_role_arn"     { value = module.lambda3.lambda_role_arn }
