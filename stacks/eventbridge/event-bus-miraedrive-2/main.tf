module "event_bus_miraedrive_2" {
  source = "../../../modules/eventbridge/event-bus-miraedrive-2"

  bus_name               = "event-bus-miraedrive-2"
  tags                   = var.tags

  # StepFunctions Target
  step_function_arn      = var.step_function_arn

  # Schema Discovery (verwaltete Schemas-Rule)
  enable_schema_discovery = var.enable_schema_discovery

  # CloudWatch Logs
  create_error_log_group = var.create_error_log_group
  log_group_name_error   = "/aws/vendedlogs/events/event-bus/event-bus-miraedrive-2"

  # S3 ERROR Logging
  enable_s3_error_logging = var.enable_s3_error_logging
  s3_bucket_name          = var.s3_bucket_name
  s3_prefix               = "AWSLogs"
  s3_error_folder         = "EventBusLogs"

  # Vorsicht PII
  include_execution_data  = var.include_execution_data
}

output "event_bus_name"  { value = module.event_bus_miraedrive_2.event_bus_name }
output "event_bus_arn"   { value = module.event_bus_miraedrive_2.event_bus_arn }
output "rule_to_sfn_arn" { value = module.event_bus_miraedrive_2.rule_to_sfn_arn }
output "target_role_arn" { value = module.event_bus_miraedrive_2.target_role_arn }

output "log_group_error_name"       { value = module.event_bus_miraedrive_2.log_group_error_name }
output "s3_delivery_source_name"    { value = module.event_bus_miraedrive_2.s3_delivery_source_name }
output "s3_delivery_destination_arn"{ value = module.event_bus_miraedrive_2.s3_delivery_destination_arn }
