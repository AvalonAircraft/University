############################
# Inputs
############################
variable "role_name"          { type = string }                      # z.B. "StepFunctions-AgentStepFunction2-role"
variable "role_path"          { type = string,  default = "/service-role/" }
variable "lambda_resources"   { type = list(string) }                # erlaubte Lambda-ARNs (scoped, wildcard ok)
variable "log_group_arns"     { type = list(string) }                # Ziel-LogGroups (für Put*; Create braucht *)
variable "tags"               { type = map(string), default = {} }

# Optional: Wenn ich zentrale Policies anhängen möchte, nicht neu erstellen
variable "create_managed_policies"      { type = bool,        default = true }
variable "existing_managed_policy_arns" { type = list(string), default = [] }

data "aws_partition" "current" {}
data "aws_region"     "current" {}
data "aws_caller_identity" "current" {}

############################
# Trust policy (Step Functions)
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
# Managed Policy (local): CloudWatch Logs delivery
# HINWEIS:
# - logs:CreateLogGroup MUSS Resource="*" haben (LogGroup existiert noch nicht).
# - Für CreateLogStream/PutLogEvents/PutRetentionPolicy darf/muss ich einschränken.
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
      "logs:PutRetentionPolicy",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = var.log_group_arns
  }
}

resource "aws_iam_policy" "cw_logs" {
  count       = var.create_managed_policies ? 1 : 0
  name        = "StepFn-CloudWatchLogsAccess"
  description = "Allow Step Functions to create/write to specified CloudWatch Logs groups"
  policy      = data.aws_iam_policy_document.cw_logs.json
}

############################
# Managed Policy (local): Lambda Invoke scoped
############################
data "aws_iam_policy_document" "lambda_invoke_scoped" {
  statement {
    sid     = "InvokeAllowedLambdas"
    effect  = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync"
    ]
    resources = var.lambda_resources
  }
}

resource "aws_iam_policy" "lambda_invoke_scoped" {
  count       = var.create_managed_policies ? 1 : 0
  name        = "StepFn-LambdaInvokeScoped"
  description = "Allow Step Functions to invoke specific Lambda functions (scoped)"
  policy      = data.aws_iam_policy_document.lambda_invoke_scoped.json
}

############################
# Managed Policy (local): X-Ray
############################
data "aws_iam_policy_document" "xray" {
  statement {
    sid     = "XRayAccess"
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
  description = "Allow Step Functions to send X-Ray traces/telemetry"
  policy      = data.aws_iam_policy_document.xray.json
}

############################
# Inline Policy: Logs Fallback (nur minimal: Create + Put auf *)
# (Optional; ich lasse sie drin, weil deine Konsole das auch hatte)
############################
data "aws_iam_policy_document" "inline_lambda" {
  statement {
    effect  = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync"
    ]
    resources = var.lambda_resources
  }

  statement {
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

############################
# Role + Attachments
############################
resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_states.json
  tags               = var.tags
}

# Inline-Policy "Lambda"
resource "aws_iam_role_policy" "inline_lambda" {
  name   = "Lambda"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline_lambda.json
}

# Attach locally-created managed policies (optional)
resource "aws_iam_role_policy_attachment" "attach_cw" {
  count      = var.create_managed_policies ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.cw_logs[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_lambda_invoke_scoped" {
  count      = var.create_managed_policies ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.lambda_invoke_scoped[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_xray" {
  count      = var.create_managed_policies ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.xray[0].arn
}

# Attach centrally-managed policies (falls übergeben)
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
