# Module: IAM-StepFunctions-Agent-Orchestrator


terraform {
  required_version = ">= 1.5.0"
}

data "aws_partition" "current" {}
data "aws_region"    "current" {}
data "aws_caller_identity" "current" {}


# Locals for Naming

locals {
  # Verhindert Namenskollisionen, wenn das Modul mehrfach genutzt wird
  policy_suffix = var.role_name
}


# Trust Policy

data "aws_iam_policy_document" "trust_states" {
  statement {
    sid     = "StepFunctionsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}


# CloudWatch Logs Policy

data "aws_iam_policy_document" "cw_logs" {
  statement {
    sid       = "AllowCreateLogGroup"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"] # Notwendig, da die Gruppe beim ersten Schreibversuch oft noch nicht existiert
  }
  statement {
    sid    = "AllowLogStreamOperations"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy"
    ]
    # Falls die ARNs in der Liste kein ":*" am Ende haben, fügen wir es hier zur Sicherheit hinzu
    resources = [for arn in var.log_group_arns : "${replace(arn, ":*", "")}:*"]
  }
}

resource "aws_iam_policy" "cw_logs" {
  count       = var.create_managed_policies ? 1 : 0
  name        = "StepFn-Logs-${local.policy_suffix}"
  description = "Logging permissions for Step Function ${var.role_name}"
  policy      = data.aws_iam_policy_document.cw_logs.json
  tags        = var.tags
}


# Lambda Invoke Policy

data "aws_iam_policy_document" "lambda_invoke" {
  statement {
    sid    = "InvokeScopedLambdas"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync"
    ]
    resources = var.lambda_arns
  }
}

resource "aws_iam_policy" "lambda_invoke_scoped" {
  count       = var.create_managed_policies ? 1 : 0
  name        = "StepFn-Invoke-${local.policy_suffix}"
  description = "Scoped Lambda invocation for ${var.role_name}"
  policy      = data.aws_iam_policy_document.lambda_invoke.json
  tags        = var.tags
}


# X-Ray Policy

data "aws_iam_policy_document" "xray" {
  statement {
    sid    = "XRayWriteTelemetry"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "xray" {
  count       = var.create_managed_policies ? 1 : 0
  name        = "StepFn-XRay-${local.policy_suffix}"
  description = "X-Ray tracing permissions for ${var.role_name}"
  policy      = data.aws_iam_policy_document.xray.json
  tags        = var.tags
}


# Role Execution

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_states.json
  tags               = var.tags
}

# Dynamisches Attachment der erzeugten Policies
locals {
  created_policy_arns = var.create_managed_policies ? [
    aws_iam_policy.cw_logs[0].arn,
    aws_iam_policy.lambda_invoke_scoped[0].arn,
    aws_iam_policy.xray[0].arn
  ] : []
  
  all_arns = concat(local.created_policy_arns, var.existing_managed_policy_arns)
}

resource "aws_iam_role_policy_attachment" "unified" {
  for_each   = toset(local.all_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}


# Outputs

output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
