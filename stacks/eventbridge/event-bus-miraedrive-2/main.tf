# Optional: resolve StepFunction ARN by name (portable)

data "aws_sfn_state_machine" "target" {
  count = var.step_function_arn == "" && var.step_function_name != "" ? 1 : 0
  name  = var.step_function_name
}

locals {
  resolved_step_function_arn = coalesce(
    nullif(var.step_function_arn, ""),
    try(data.aws_sfn_state_machine.target[0].arn, null)
  )
}


# Module call

module "event_bus_miraedrive_2" {
  source = "../../../modules/eventbridge/event-bus-miraedrive-2"

  bus_name = var.bus_name
  tags     = var.tags

  # StepFunctions Target (ARN muss am Ende gesetzt sein)
  step_function_arn = local.resolved_step_function_arn

  # Schema Discovery (verwaltete Schemas-Rule)
  enable_schema_discovery = var.enable_schema_discovery

  # CloudWatch Logs
  create_error_log_group = var.create_error_log_group
  log_group_name_error   = var.log_group_name_error

  # S3 ERROR Logging
  enable_s3_error_logging = var.enable_s3_error_logging
  s3_bucket_name          = var.s3_bucket_name
  s3_prefix               = var.s3_prefix
  s3_error_folder         = var.s3_error_folder

  # Vorsicht PII
  include_execution_data = var.include_execution_data
}


# Outputs

output "event_bus_name"   { value = module.event_bus_miraedrive_2.event_bus_name }
output "event_bus_arn"    { value = module.event_bus_miraedrive_2.event_bus_arn }
output "rule_to_sfn_arn"  { value = module.event_bus_miraedrive_2.rule_to_sfn_arn }
output "target_role_arn"  { value = module.event_bus_miraedrive_2.target_role_arn }

output "log_group_error_name"         { value = module.event_bus_miraedrive_2.log_group_error_name }
output "s3_delivery_source_name"      { value = module.event_bus_miraedrive_2.s3_delivery_source_name }
output "s3_delivery_destination_arn"  { value = module.event_bus_miraedrive_2.s3_delivery_destination_arn }
