# Module: Event-Bus-Miraedrive (Central Logging)


terraform {
  required_version = ">= 1.5.0"
}

data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}


# Inputs

variable "bus_name" {
  type    = string
  default = "event-bus-miraedrive"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_error_log_group" {
  type    = bool
  default = true
}

variable "log_group_name_error" {
  type    = string
  default = "/aws/vendedlogs/events/event-bus/event-bus-miraedrive"
}

variable "enable_s3_error_logging" {
  type    = bool
  default = true
}

variable "s3_bucket_name" {
  type    = string
  default = "miraedrive-assets"
}

variable "s3_prefix" {
  type    = string
  default = "AWSLogs"
}

variable "s3_error_folder" {
  type    = string
  default = "EventBusLogs"
}

variable "include_execution_data" {
  type    = bool
  default = false
}


# Event Bus

resource "aws_cloudwatch_event_bus" "this" {
  name = var.bus_name
  tags = merge(var.tags, { Name = var.bus_name })
}


# CloudWatch Error Logging

resource "aws_cloudwatch_log_group" "error" {
  count             = var.create_error_log_group ? 1 : 0
  name              = var.log_group_name_error
  retention_in_days = 30
  tags              = merge(var.tags, { Name = "${var.bus_name}-error-logs" })
}


# Vended Logs Delivery (S3)

resource "aws_cloudwatchlogs_delivery_destination" "s3_error" {
  count            = var.enable_s3_error_logging ? 1 : 0
  name             = "EB-S3-Dest-${var.bus_name}"
  destination_type = "S3"

  s3 {
    bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}"
    prefix     = "${var.s3_prefix}/${data.aws_caller_identity.current.account_id}/${var.s3_error_folder}/"
  }
}

resource "aws_cloudwatchlogs_delivery_source" "eventbridge_error" {
  count                = var.enable_s3_error_logging ? 1 : 0
  name                 = "EB-Source-${var.bus_name}"
  delivery_source_type = "EVENTBRIDGE"

  eventbridge {
    event_bus_arn          = aws_cloudwatch_event_bus.this.arn
    log_level              = "ERROR"
    include_execution_data = var.include_execution_data
  }
}

resource "aws_cloudwatchlogs_delivery" "eventbridge_error_to_s3" {
  count = var.enable_s3_error_logging ? 1 : 0

  delivery_source_name     = aws_cloudwatchlogs_delivery_source.eventbridge_error[0].name
  delivery_destination_arn = aws_cloudwatchlogs_delivery_destination.s3_error[0].arn
  record_fields            = ["timestamp", "message", "service", "level", "eventBusName", "region", "accountId"]
}


# Outputs

output "event_bus_name" { value = aws_cloudwatch_event_bus.this.name }
output "event_bus_arn"  { value = aws_cloudwatch_event_bus.this.arn }

output "log_group_error_name" {
  value = var.create_error_log_group ? aws_cloudwatch_log_group.error[0].name : null
}
