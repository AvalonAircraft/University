# Module: Event-Bus-Miraedrive-2 (SFN Orchestrator)


terraform {
  required_version = ">= 1.5.0"
}

data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}
data "aws_partition"       "current" {}



# Event Bus & Discovery


resource "aws_cloudwatch_event_bus" "this" {
  name = var.bus_name
  tags = merge(var.tags, { Name = var.bus_name })
}

resource "aws_schemas_discoverer" "this" {
  count       = var.enable_schema_discovery ? 1 : 0
  source_arn  = aws_cloudwatch_event_bus.this.arn
  description = "Schema discovery for ${var.bus_name}"
  tags        = merge(var.tags, { Name = "${var.bus_name}-schemas" })
}


# Rule → Step Functions


resource "aws_cloudwatch_event_rule" "to_sfn" {
  name           = "To_StepFunction"
  description    = "Route EmailAnalyzed events to StepFunctions"
  event_bus_name = aws_cloudwatch_event_bus.this.name

  event_pattern = jsonencode({
    source      = ["app.email-agent"]
    detail-type = ["EmailAnalyzed"]
  })

  tags = merge(var.tags, { Name = "To_StepFunction" })
}


# Target IAM Role (Die "Perfekte" Rolle)


resource "aws_iam_role" "events_to_sfn_role" {
  name = "EB-Invoke-SFN-${var.bus_name}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy" "events_to_sfn_inline" {
  name = "AllowStartExecution"
  role = aws_iam_role.events_to_sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = var.step_function_arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "to_sfn" {
  rule           = aws_cloudwatch_event_rule.to_sfn.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn            = var.step_function_arn
  role_arn       = aws_iam_role.events_to_sfn_role.arn
}


# Error Logging (CloudWatch & S3 Delivery)


# 1. CloudWatch Log Group
resource "aws_cloudwatch_log_group" "error" {
  count             = var.create_error_log_group ? 1 : 0
  name              = var.log_group_name_error
  retention_in_days = 30
  tags              = var.tags
}

# 2. Vended Logs Delivery Destination (S3)
resource "aws_cloudwatchlogs_delivery_destination" "s3_error" {
  count            = var.enable_s3_error_logging ? 1 : 0
  name             = "EB-S3-Dest-${var.bus_name}"
  destination_type = "S3"

  s3 {
    bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}"
    prefix     = "${var.s3_prefix}/${data.aws_caller_identity.current.account_id}/${var.s3_error_folder}/"
  }
}

# 3. Delivery Source (EventBridge ERROR level)
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

# 4. The actual Delivery Link
resource "aws_cloudwatchlogs_delivery" "eventbridge_error_to_s3" {
  count = var.enable_s3_error_logging ? 1 : 0

  delivery_source_name     = aws_cloudwatchlogs_delivery_source.eventbridge_error[0].name
  delivery_destination_arn = aws_cloudwatchlogs_delivery_destination.s3_error[0].arn
  
  # Felder für bessere Analyse in Athena/S3
  record_fields = ["timestamp", "message", "service", "level", "eventBusName", "region", "accountId"]
}

# ... (Outputs bleiben wie definiert) ...
