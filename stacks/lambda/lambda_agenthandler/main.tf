module "lambda_agenthandler" {
  source = "../../modules/lambda_agenthandler"

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

  # STRIKT: EventBridge nur für diesen Bus erlauben
  event_bus_name = var.event_bus_name

  # VPC
  attach_vpc_access  = var.attach_vpc_access
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Env/Tags/Rolle
  env = merge(
    var.env,
    {
      EVENT_BUS_NAME = var.event_bus_name
      REGION         = var.region
    }
  )
  tags             = var.tags
  role_name_suffix = var.role_name_suffix
}

output "lambda_function_arn" { value = module.lambda_agenthandler.lambda_function_arn }
output "lambda_role_arn"     { value = module.lambda_agenthandler.lambda_role_arn }
