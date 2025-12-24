############################
# Module: event-bus-miraedrive-2
############################
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}
data "aws_partition"       "current" {}

############################
# Inputs
############################
variable "bus_name"  { type = string, default = "event-bus-miraedrive-2" }
variable "tags"      { type = map(string), default = {} }

# StepFunctions Target
variable "step_function_arn" { type = string }

# Schema discovery (ermöglicht die verwaltete Schemas-Rule)
variable "enable_schema_discovery" { type = bool, default = true }

# CloudWatch Logs (ERROR)
variable "create_error_log_group" { type = bool,   default = true }
variable "log_group_name_error"   { type = string, default = "/aws/vendedlogs/events/event-bus/event-bus-miraedrive-2" }

# S3 ERROR logging via CloudWatch Logs Delivery
variable "enable_s3_error_logging" { type = bool,   default = true }
variable "s3_bucket_name"          { type = string, default = "miraedrive-assets" }
variable "s3_prefix"               { type = string, default = "AWSLogs" }
variable "s3_error_folder"         { type = string, default = "EventBusLogs" }

# Optional: Execution data (Request/Response payloads – Achtung PII)
variable "include_execution_data"  { type = bool, default = false }

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
# (Optional) Schema Discovery
############################
resource "aws_schemas_discoverer" "this" {
  count       = var.enable_schema_discovery ? 1 : 0
  source_arn  = aws_cloudwatch_event_bus.this.arn
  description = "Schema discovery for ${var.bus_name}"
  tags        = merge(local.tags, { Name = "${var.bus_name}-schemas" })
}

############################
# Rule → Step Functions (To_StepFunction)
############################
resource "aws_cloudwatch_event_rule" "to_sfn" {
  name           = "To_StepFunction"
  description    = "Route EmailAnalyzed events from app.email-agent to StepFunctions"
  event_bus_name = aws_cloudwatch_event_bus.this.name

  event_pattern = jsonencode({
    source        = ["app.email-agent"]
    "detail-type" = ["EmailAnalyzed"]
  })

  tags = merge(local.tags, { Name = "To_StepFunction" })
}

# Target Role: EventBridge darf StepFunctions starten
data "aws_iam_policy_document" "target_assume" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["events.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "events_to_sfn_role" {
  name               = "Amazon_EventBridge_Invoke_Step_Functions_${var.bus_name}"
  assume_role_policy = data.aws_iam_policy_document.target_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "events_to_sfn_policy" {
  statement {
    effect   = "Allow"
    actions  = ["states:StartExecution"]
    resources = [var.step_function_arn]
  }
}

resource "aws_iam_role_policy" "events_to_sfn_inline" {
  name   = "AllowStartExecution-${var.bus_name}"
  role   = aws_iam_role.events_to_sfn_role.id
  policy = data.aws_iam_policy_document.events_to_sfn_policy.json
}

resource "aws_cloudwatch_event_target" "to_sfn" {
  rule           = aws_cloudwatch_event_rule.to_sfn.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn            = var.step_function_arn
  role_arn       = aws_iam_role.events_to_sfn_role.arn
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
# Hinweis: benötigt einen aktuellen AWS Provider (≈ v5.60+)
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
  record_fields            = ["timestamp","message","service","level","eventBusName","region","accountId"]

  tags = merge(local.tags, { Name = "EventBusErrorDelivery-${var.bus_name}-toS3" })

  depends_on = [
    aws_cloudwatchlogs_delivery_source.eventbridge_error,
    aws_cloudwatchlogs_delivery_destination.s3_error
  ]
}

############################
# Outputs
############################
output "event_bus_name"  { value = aws_cloudwatch_event_bus.this.name }
output "event_bus_arn"   { value = aws_cloudwatch_event_bus.this.arn }
output "rule_to_sfn_arn" { value = aws_cloudwatch_event_rule.to_sfn.arn }
output "target_role_arn" { value = aws_iam_role.events_to_sfn_role.arn }

output "log_group_error_name" {
  value = var.create_error_log_group ? aws_cloudwatch_log_group.error[0].name : null
}

output "s3_delivery_source_name" {
  value = var.enable_s3_error_logging ? aws_cloudwatchlogs_delivery_source.eventbridge_error[0].name : null
}

output "s3_delivery_destination_arn" {
  value = var.enable_s3_error_logging ? aws_cloudwatchlogs_delivery_destination.s3_error[0].arn : null
}
