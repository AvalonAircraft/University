# Module: StepFunction-Full-Pipeline (Express)


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ... (Data Sources & Inputs bleiben identisch) ...


# IAM Role Logic


locals {
  use_ext_role      = length(var.existing_role_arn) > 0
  use_ext_log_group = length(var.existing_log_group_arn) > 0
  
  # Finaler Role ARN
  role_arn = local.use_ext_role ? var.existing_role_arn : aws_iam_role.sfn_role[0].arn

  # CloudWatch ARN Logik (mit Fallback)
  log_destination_arn = var.enable_logging ? (
    local.use_ext_log_group 
    ? var.existing_log_group_arn 
    : (var.create_log_group ? "${aws_cloudwatch_log_group.sfn[0].arn}:*" : null)
  ) : null
}

# IAM Ressourcen (nur wenn keine externe Rolle geliefert wird)
resource "aws_iam_role" "sfn_role" {
  count = local.use_ext_role ? 0 : 1
  name  = "service-role-${var.state_machine_name}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "sfn_policy" {
  count = local.use_ext_role ? 0 : 1
  name  = "SFN-Execution-Policy"
  role  = aws_iam_role.sfn_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = [var.lambda1_fn, var.lambda2_fn, var.lambda3_fn, var.lambda4_fn, var.lambda5_fn, var.lambda6_fn]
      },
      {
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}


# CloudWatch Log Group


resource "aws_cloudwatch_log_group" "sfn" {
  count             = var.enable_logging && !local.use_ext_log_group && var.create_log_group ? 1 : 0
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
  tags              = var.tags
}


# State Machine


resource "aws_sfn_state_machine" "this" {
  name     = var.state_machine_name
  role_arn = local.role_arn
  type     = "EXPRESS"
  
  definition = local.definition

  dynamic "logging_configuration" {
    for_each = local.log_destination_arn != null ? [1] : []
    content {
      include_execution_data = var.include_execution_data
      level                  = var.log_level
      log_destination        = local.log_destination_arn
    }
  }

  tags = var.tags
}


# Outputs

output "state_machine_arn" { value = aws_sfn_state_machine.this.arn }
output "state_machine_name" { value = aws_sfn_state_machine.this.name }
