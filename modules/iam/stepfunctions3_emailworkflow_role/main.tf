# Module: IAM-StepFunctions-Orchestrator


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ... (Inputs bleiben identisch) ...


# Locals

locals {
  # Dynamische Präfixe für bessere Übersicht in der IAM-Konsole
  policy_prefix = "StepFn-${var.role_name}"
}


# Trust Policy (Step Functions)

data "aws_iam_policy_document" "trust_states" {
  statement {
    sid     = "AllowStatesToAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}


# Managed Policies (Conditional)


# 1. Lambda Invoke (Scoped)
data "aws_iam_policy_document" "lambda_invoke_scoped" {
  statement {
    sid       = "InvokeFunctions"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = var.lambda_resources
  }
}

resource "aws_iam_policy" "lambda_invoke_scoped" {
  count       = var.create_managed_policies ? 1 : 0
  name        = "${local.policy_prefix}-LambdaInvoke"
  description = "Allows Step Functions to invoke specific Lambda functions for MiraeDrive"
  policy      = data.aws_iam_policy_document.lambda_invoke_scoped.json
  tags        = var.tags
}

# 2. X-Ray Access (Standard für Observability)
data "aws_iam_policy_document" "xray" {
  statement {
    sid    = "XRayTelemetry"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "xray" {
  count       = var.create_managed_policies ? 1 : 0
  name        = "${local.policy_prefix}-XRay"
  description = "Allows Step Functions to send traces to AWS X-Ray"
  policy      = data.aws_iam_policy_document.xray.json
  tags        = var.tags
}


# Role + Attachments

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_states.json
  tags               = var.tags
}

# Zentrale Inline-Policy für Logs (da dies fast immer Rollen-spezifisch ist)
resource "aws_iam_role_policy" "logs" {
  name = "CloudWatchLogsAccess"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# Kombination der Policy Attachments (Lokal + Bestehend)
locals {
  all_policy_arns = concat(
    var.create_managed_policies ? [aws_iam_policy.lambda_invoke_scoped[0].arn, aws_iam_policy.xray[0].arn] : [],
    var.existing_managed_policy_arns
  )
}

resource "aws_iam_role_policy_attachment" "unified" {
  for_each   = toset(local.all_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}


# Outputs

output "role_arn"  { value = aws_iam_role.this.arn }
output "role_name" { value = aws_iam_role.this.name }
