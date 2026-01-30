# Module: StepFunction-Tenant-Router (Standard)


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ... (Data Sources & Inputs bleiben wie von dir definiert) ...

locals {
  tags    = var.tags
  use_ext = length(var.existing_role_arn) > 0

  # WICHTIG: SFN benötigt :* am Ende der Log Group ARN
  log_destination_arn = var.enable_logging ? (
    length(var.existing_log_group_arn) > 0
      ? (var.existing_log_group_arn)
      : (var.create_log_group ? "${aws_cloudwatch_log_group.sfn[0].arn}:*" : null)
  ) : null
}


# IAM Role Logic


resource "aws_iam_role" "sfn_role" {
  count              = local.use_ext ? 0 : 1
  name               = "service-role-${var.state_machine_name}"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
}

resource "aws_iam_role_policy" "sfn_policy" {
  count = local.use_ext ? 0 : 1
  name  = "SFN-TenantRouter-Policy"
  role  = aws_iam_role.sfn_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = [
          var.lambda_resolve_tenant_arn,
          var.lambda_move_email_arn,
          var.lambda_forward_vpc_arn
        ]
      },
      {
        # Berechtigungen für CloudWatch Logs (vended logs)
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


# State Machine (STANDARD)


resource "aws_sfn_state_machine" "this" {
  name     = var.state_machine_name
  role_arn = local.use_ext ? var.existing_role_arn : aws_iam_role.sfn_role[0].arn
  type     = "STANDARD" # Ermöglicht Visualisierung & Langzeit-Retries
  
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

output "state_machine_arn" { value = aws_sfn_state_machine.this.arn }
