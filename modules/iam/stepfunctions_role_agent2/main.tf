# Module: IAM-StepFunctions-Orchestrator-V2


terraform {
  required_version = ">= 1.5.0"
}

data "aws_partition" "current" {}


# Inputs

variable "role_name"        { type = string }
variable "role_path"        { type = string, default = "/service-role/" }
variable "lambda_resources" { type = list(string) }
variable "log_group_arns"   { type = list(string) }
variable "tags"             { type = map(string), default = {} }

variable "create_managed_policies"      { type = bool, default = true }
variable "existing_managed_policy_arns" { type = list(string), default = [] }


# Trust Policy

data "aws_iam_policy_document" "trust_states" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}


# Managed Policies (Local)


# 1. CloudWatch Logs
data "aws_iam_policy_document" "cw_logs" {
  statement {
    sid       = "AllowLogGroupCreation"
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"]
  }
  statement {
    sid       = "AllowLogWriting"
    actions   = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = var.log_group_arns
  }
}

resource "aws_iam_policy" "cw_logs" {
  count  = var.create_managed_policies ? 1 : 0
  name   = "StepFn-Logs-${var.role_name}"
  policy = data.aws_iam_policy_document.cw_logs.json
}

# 2. Lambda Invoke
data "aws_iam_policy_document" "lambda_invoke" {
  statement {
    actions   = ["lambda:InvokeFunction", "lambda:InvokeAsync"]
    resources = var.lambda_resources
  }
}

resource "aws_iam_policy" "lambda_invoke" {
  count  = var.create_managed_policies ? 1 : 0
  name   = "StepFn-Invoke-${var.role_name}"
  policy = data.aws_iam_policy_document.lambda_invoke.json
}

# 3. X-Ray
data "aws_iam_policy_document" "xray" {
  statement {
    actions   = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "xray" {
  count  = var.create_managed_policies ? 1 : 0
  name   = "StepFn-XRay-${var.role_name}"
  policy = data.aws_iam_policy_document.xray.json
}


# Role Execution

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_states.json
  tags               = var.tags
}

# Wir nutzen ein dynamisches Set an Attachments, um den Code DRY zu halten
locals {
  local_policy_arns = var.create_managed_policies ? [
    aws_iam_policy.cw_logs[0].arn,
    aws_iam_policy.lambda_invoke[0].arn,
    aws_iam_policy.xray[0].arn
  ] : []
  
  all_policy_arns = concat(local_local_policy_arns, var.existing_managed_policy_arns)
}

resource "aws_iam_role_policy_attachment" "unified" {
  for_each   = toset(local.all_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}


# Outputs

output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
