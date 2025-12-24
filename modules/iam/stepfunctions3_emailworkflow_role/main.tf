############################
# Inputs (vom Stack befüllt)
############################
variable "role_name" {
  description = "Name der Step Functions IAM-Rolle"
  type        = string
}

variable "role_path" {
  description = "IAM Role path"
  type        = string
  default     = "/service-role/"
}

# Liste von Lambda-ARNs (oder Wildcards wie arn:aws:lambda:*:*:function:Lambda*)
variable "lambda_resources" {
  description = "Ziel-Lambda-ARNs, die die Rolle invoken darf"
  type        = list(string)
}

variable "tags" {
  description = "Zusätzliche Tags"
  type        = map(string)
  default     = {}
}

# Optional: Wenn ich bereits zentral verwaltete Policies habe, kann ich deren ARNs angeben;
# in dem Fall werden die lokalen Managed Policies nicht erstellt.
variable "existing_managed_policy_arns" {
  description = "Bereits existierende Managed Policy ARNs, die an die Rolle angehängt werden sollen"
  type        = list(string)
  default     = []
}

# Schalter: Sollen die lokalen Managed Policies erstellt werden?
variable "create_managed_policies" {
  description = "Erstelle die Managed Policies lokal (true) oder nutze nur existing_managed_policy_arns (false)"
  type        = bool
  default     = true
}

############################
# Locals
############################
locals {
  # Saubere, kollisionsarme Namen ohne hart codierte GUIDs:
  lambda_invoke_policy_name = "${var.role_name}-LambdaInvokeScoped"
  xray_policy_name          = "${var.role_name}-XRayAccess"
}

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
# Managed Policy (lokal): LambdaInvokeScoped
############################
data "aws_iam_policy_document" "lambda_invoke_scoped" {
  statement {
    sid     = "InvokeScoped"
    effect  = "Allow"
    actions = [
      "lambda:InvokeFunction"
      # "lambda:InvokeAsync"  # legacy – bewusst NICHT eingeschlossen
    ]
    resources = var.lambda_resources
  }
}

resource "aws_iam_policy" "lambda_invoke_scoped" {
  count       = var.create_managed_policies ? 1 : 0
  name        = local.lambda_invoke_policy_name
  description = "Allow Step Functions to invoke the specified Lambda functions"
  policy      = data.aws_iam_policy_document.lambda_invoke_scoped.json
}

############################
# Managed Policy (lokal): XRayAccess
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
  name        = local.xray_policy_name
  description = "Allow Step Functions to send X-Ray traces/telemetry"
  policy      = data.aws_iam_policy_document.xray.json
}

############################
# Inline Policy: Logs + Lambda Invoke (eher minimal)
############################
data "aws_iam_policy_document" "inline_lambda" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = var.lambda_resources
  }

  statement {
    effect = "Allow"
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

# Attach lokal erstellte Managed Policies (falls aktiviert)
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

# Attach bereits existierende Managed Policies (wenn angegeben)
resource "aws_iam_role_policy_attachment" "attach_existing" {
  for_each   = toset(var.existing_managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

############################
# Outputs
############################
output "role_name" {
  value = aws_iam_role.this.name
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
