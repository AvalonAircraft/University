module "event_bus_miraedrive" {
  source = "../../../modules/eventbridge/event-bus-miraedrive"

  bus_name = "event-bus-miraedrive"
  tags     = var.tags

  # CloudWatch Logs
  create_error_log_group = var.create_error_log_group
  log_group_name_error   = "/aws/vendedlogs/events/event-bus/event-bus-miraedrive"

  # S3 ERROR Logging
  enable_s3_error_logging = var.enable_s3_error_logging
  s3_bucket_name          = var.s3_bucket_name
  s3_prefix               = "AWSLogs"
  s3_error_folder         = "EventBusLogs"

  include_execution_data  = var.include_execution_data
}

output "event_bus_name" { value = module.event_bus_miraedrive.event_bus_name }
output "event_bus_arn"  { value = module.event_bus_miraedrive.event_bus_arn }

output "log_group_error_name" {
  value = module.event_bus_miraedrive.log_group_error_name
}
output "s3_delivery_source_name" {
  value = module.event_bus_miraedrive.s3_delivery_source_name
}
output "s3_delivery_destination_arn" {
  value = module.event_bus_miraedrive.s3_delivery_destination_arn
}
