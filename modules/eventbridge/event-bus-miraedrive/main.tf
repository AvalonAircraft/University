############################
# Module: event-bus-miraedrive
############################
data "aws_partition" "current" {}
data "aws_region"    "current" {}

############################
# Inputs
############################
variable "bus_name"  { type = string, default = "event-bus-miraedrive" }
variable "tags"      { type = map(string), default = {} }

# CloudWatch Logs (ERROR)
variable "create_error_log_group" { type = bool,   default = true }
variable "log_group_name_error"   { type = string, default = "/aws/vendedlogs/events/event-bus/event-bus-miraedrive" }

# S3 ERROR logging via CloudWatch Logs Delivery
variable "enable_s3_error_logging" { type = bool,   default = true }
variable "s3_bucket_name"          { type = string, default = "miraedrive-assets" }
variable "s3_prefix"               { type = string, default = "AWSLogs" }
variable "s3_error_folder"         { type = string, default = "EventBusLogs" }

# Optional: Execution data (Request/Response payloads) – Vorsicht PII
variable "include_execution_data"  { type = bool, default = false }

############################
# Env
############################
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}

locals {
  tags = var.tags
}

############################
# Event Bus
############################
resource "aws_cloudwatch_event_bus" "this" {
  name = var.bus_name
  tags = merge(local.tags, { Name = var.bus_name })
}

############################
# CloudWatch Log Group (ERROR)
############################
resource "aws_cloudwatch_log_group" "error" {
  count             = var.create_error_log_group ? 1 : 0
  name              = var.log_group_name_error
  retention_in_days = 30
  tags              = merge(local.tags, { Name = "${var.bus_name}-error-logs" })
}

############################
# CloudWatch Logs Delivery → S3 (ERROR)
# Hinweis: benötigt einen aktuellen AWS Provider (~5.60+)
############################
resource "aws_cloudwatchlogs_delivery_destination" "s3_error" {
  count            = var.enable_s3_error_logging ? 1 : 0
  name             = "EventBusS3Destination-${var.bus_name}-ERROR"
  destination_type = "S3"

  s3 {
    bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}"
    prefix     = "${var.s3_prefix}/${data.aws_caller_identity.current.account_id}/${var.s3_error_folder}/"
  }

  tags = merge(local.tags, { Name = "EventBusS3Dest-${var.bus_name}-ERROR" })
}

resource "aws_cloudwatchlogs_delivery_source" "eventbridge_error" {
  count                = var.enable_s3_error_logging ? 1 : 0
  name                 = "EventBusSource-${var.bus_name}-ERROR_LOGS"
  delivery_source_type = "EVENTBRIDGE"

  eventbridge {
    event_bus_arn          = aws_cloudwatch_event_bus.this.arn
    log_level              = "ERROR"
    include_execution_data = var.include_execution_data
  }

  tags = merge(local.tags, { Name = "EventBusSource-${var.bus_name}-ERROR" })
}

resource "aws_cloudwatchlogs_delivery" "eventbridge_error_to_s3" {
  count = var.enable_s3_error_logging ? 1 : 0

  delivery_source_name     = aws_cloudwatchlogs_delivery_source.eventbridge_error[0].name
  delivery_destination_arn = aws_cloudwatchlogs_delivery_destination.s3_error[0].arn

  # sinnvolle Standardfelder
  record_fields = ["timestamp", "message", "service", "level", "eventBusName", "region", "accountId"]

  tags = merge(local.tags, { Name = "EventBusErrorDelivery-${var.bus_name}-toS3" })

  depends_on = [
    aws_cloudwatchlogs_delivery_source.eventbridge_error,
    aws_cloudwatchlogs_delivery_destination.s3_error
  ]
}

############################
# Outputs
############################
output "event_bus_name" { value = aws_cloudwatch_event_bus.this.name }
output "event_bus_arn"  { value = aws_cloudwatch_event_bus.this.arn }

output "log_group_error_name" {
  value = var.create_error_log_group ? aws_cloudwatch_log_group.error[0].name : null
}

output "s3_delivery_source_name" {
  value = var.enable_s3_error_logging ? aws_cloudwatchlogs_delivery_source.eventbridge_error[0].name : null
}

output "s3_delivery_destination_arn" {
  value = var.enable_s3_error_logging ? aws_cloudwatchlogs_delivery_destination.s3_error[0].arn : null
}
