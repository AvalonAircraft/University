# Module: Event-Bus-Emails (S3 -> Lambda)


terraform {
  required_version = ">= 1.5.0"
}

data "aws_caller_identity" "current" {}


# Inputs

variable "bus_name"         { type = string }
variable "rule_name"        { type = string }
variable "bucket_name"      { type = string }
variable "key_prefix"       { type = string, default = "emails/" }
variable "target_lambda_arn" { type = string }
variable "dlq_arn"          { type = string, default = "" } # SQS ARN für Fehler
variable "tags"             { type = map(string), default = {} }


# IAM Role (Nur nötig, wenn DLQ genutzt wird)


# Trust Policy für den EventBridge Service
data "aws_iam_policy_document" "eb_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eb_dlq_role" {
  count              = var.dlq_arn != "" ? 1 : 0
  name               = "EB-DLQ-Role-${var.rule_name}"
  assume_role_policy = data.aws_iam_policy_document.eb_trust.json
  tags               = var.tags
}

# Berechtigung, Nachrichten in die SQS DLQ zu schreiben
resource "aws_iam_role_policy" "eb_sqs_send" {
  count = var.dlq_arn != "" ? 1 : 0
  name  = "AllowSQSSendMessage"
  role  = aws_iam_role.eb_dlq_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = var.dlq_arn
      }
    ]
  })
}


# Event Bus & Rule


resource "aws_cloudwatch_event_bus" "this" {
  name = var.bus_name
  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name           = var.rule_name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  description    = "Trigger Lambda on S3 upload: ${var.bucket_name}/${var.key_prefix}"
  
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [var.bucket_name] }
      object = { key  = [{ prefix = var.key_prefix }] }
    }
  })
  tags = var.tags
}


# Target: Lambda


resource "aws_cloudwatch_event_target" "lambda_target" {
  rule           = aws_cloudwatch_event_rule.s3_object_created.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn            = var.target_lambda_arn
  
  # Die Role ARN wird nur gesetzt, wenn eine DLQ existiert
  role_arn = var.dlq_arn != "" ? aws_iam_role.eb_dlq_role[0].arn : null

  dynamic "dead_letter_config" {
    for_each = var.dlq_arn != "" ? [1] : []
    content {
      arn = var.dlq_arn
    }
  }
}


# Permission: EB -> Lambda


resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowInvokeFromEventBridge-${var.rule_name}"
  action        = "lambda:InvokeFunction"
  function_name = var.target_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created.arn
}


# Outputs

output "event_bus_arn"  { value = aws_cloudwatch_event_bus.this.arn }
output "event_rule_arn" { value = aws_cloudwatch_event_rule.s3_object_created.arn }
