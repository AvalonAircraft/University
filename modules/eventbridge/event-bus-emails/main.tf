
# Module: event-bus-emails


data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}


# Inputs


variable "bus_name" {
  description = "z.B. 'event-bus-emails'"
  type        = string
}

variable "rule_name" {
  description = "z.B. 'Email_S3-To_Lambda'"
  type        = string
}

variable "bucket_name" {
  description = "Name des S3 Buckets"
  type        = string
}

variable "key_prefix" {
  description = "Prefix inkl. Slash"
  type        = string
  default     = "emails/"
}

variable "target_lambda_arn" {
  description = "ARN der Ziel-Lambda"
  type        = string
}

variable "dlq_arn" {
  description = "Optionale SQS DLQ ARN"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}


# Event Bus


resource "aws_cloudwatch_event_bus" "this" {
  name = var.bus_name
  tags = var.tags
}


# Rule: S3 Object Created + Prefix


locals {
  s3_event_pattern = {
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = {
        name = [var.bucket_name]
      }
      object = {
        key = [{
          prefix = var.key_prefix
        }]
      }
    }
  }
}

resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name           = var.rule_name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  description    = "Trigger Lambda when S3 object is created under ${var.bucket_name}/${var.key_prefix}"
  event_pattern  = jsonencode(local.s3_event_pattern)
  tags           = var.tags
}


# Target: Lambda


resource "aws_cloudwatch_event_target" "lambda_target" {
  rule           = aws_cloudwatch_event_rule.s3_object_created.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn            = var.target_lambda_arn

  dynamic "dead_letter_config" {
    for_each = var.dlq_arn != "" ? [1] : []
    content {
      arn = var.dlq_arn
    }
  }
}


# Permission: EventBridge → Lambda


resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowInvokeFromEventBridge-${var.rule_name}"
  action        = "lambda:InvokeFunction"
  function_name = var.target_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created.arn
}


# Outputs


output "event_bus_arn" {
  value = aws_cloudwatch_event_bus.this.arn
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.s3_object_created.arn
}

output "event_target_id" {
  value = aws_cloudwatch_event_target.lambda_target.id
}
