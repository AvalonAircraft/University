############################
# Inputs
############################
variable "role_name"        { type = string }                       # z.B. "StepFunctions-AgentStepFunction-role"
variable "role_path"        { type = string,  default = "/service-role/" }
variable "lambda_arns"      { type = list(string) }                 # Lambdas, die die State Machine aufruft
variable "log_group_arns"   { type = list(string) }                 # Ziel-LogGroups (für Put*; Create braucht *)
variable "tags"             { type = map(string), default = {} }

# Optional: lokal verwaltete Policies erzeugen oder stattdessen vorhandene anhängen
variable "create_managed_policies"      { type = bool,        default = true }
variable "existing_managed_policy_arns" { type = list(string), default = [] }

data "aws_partition" "current" {}
data "aws_region"     "current" {}
data "aws_caller_identity" "current" {}

############################
# Trust policy (StepFunctions)
############################
data "aws_iam_policy_document" "trust_states" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

############################
# CloudWatch Logs delivery (kundenverwaltet)
# WICHTIG: CreateLogGroup muss auf "*" gehen (Gruppe existiert noch nicht)
############################
data "aws_iam_policy_document" "cw_logs" {
  statement {
    sid     = "LogsCreateGroup"
    effect  = "Allow"
    actions = ["logs:CreateLogGroup"]
    resources = ["*"]
  }
  statement {
    sid     = "LogsWriteToGroups"
    effect  = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy"
    ]
    resources = var.log_group_arns
  }
}

resource "aws_iam_policy" "cw_logs" {
  count       = var.create_managed_policies ? 1 : 0
  name        = "StepFn-CloudWatchLogsAccess"
  description = "Allow Step Functions to create/write to specified CloudWatch Log groups"
  policy      = data.aws_iam_policy_document.cw_logs.json
}

############################
# Lambda invoke (kundenverwaltet)
############################
data "aws_iam_policy_document" "lambda_invoke" {
  statement {
    sid     = "InvokeAllowedLambdas"
    effect  = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync"
    ]
    resources = var.lambda_arns
  }
}

resource "aws_iam_policy" "lambda_invoke_scoped" {
  count       = var.create_managed_policies ? 1 : 0
  name        = "StepFn-LambdaInvokeScoped"
  description = "Allow Step Functions to invoke specific Lambda functions used by the state machine"
  policy      = data.aws_iam_policy_document.lambda_invoke.json
}

############################
# X-Ray (optional, falls Tracing)
############################
data "aws_iam_policy_document" "xray" {
  statement {
    sid     = "XRayWrite"
    effect  = "Allow"
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
  name        = "StepFn-XRayAccess"
  description = "Allow Step Functions to send trace segments/telemetry to X-Ray"
  policy      = data.aws_iam_policy_document.xray.json
}

############################
# Role + attachments
############################
resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_states.json
  tags               = var.tags
}

# Anhänge lokaler, eben erzeugter Policies (wenn aktiviert)
resource "aws_iam_role_policy_attachment" "attach_cw" {
  count      = var.create_managed_policies ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.cw_logs[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_invoke" {
  count      = var.create_managed_policies ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.lambda_invoke_scoped[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_xray" {
  count      = var.create_managed_policies ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.xray[0].arn
}

# …oder vorhandene, zentral verwaltete Policies anhängen
resource "aws_iam_role_policy_attachment" "attach_existing" {
  for_each   = toset(var.existing_managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

############################
# Outputs
############################
output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn  }
