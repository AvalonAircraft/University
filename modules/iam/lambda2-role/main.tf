data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

############################
# Inputs
############################
variable "role_name"         { type = string }
variable "role_path"         { type = string,  default = "/service-role/" }
variable "policy_arns"       { type = list(string), default = [] } # managed policies to attach
variable "bedrock_model_arn" { type = string } # arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/...
variable "allow_streaming"   { type = bool, default = false }      # optional: InvokeModelWithResponseStream
variable "tags"              { type = map(string),   default = {} }

# Guards
variable "role_name" {
  type = string

  validation {
    condition     = length(var.role_name) > 0
    error_message = "role_name darf nicht leer sein."
  }
}


variable "bedrock_model_arn" {
  type = string

  validation {
    condition = can(
      regex(
        "^arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/.+$",
        var.bedrock_model_arn
      )
    )
    error_message = "bedrock_model_arn muss ein Foundation-Model-ARN der aktuellen Partition/Region sein."
  }
}


############################
# Trust policy (Lambda)
############################
data "aws_iam_policy_document" "trust_lambda" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["lambda.amazonaws.com"] }
    actions    = ["sts:AssumeRole"]
  }
}

############################
# IAM Role
############################
resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_lambda.json
  tags               = var.tags
}

############################
# Attach managed policies (customer- oder aws-managed)
############################
resource "aws_iam_role_policy_attachment" "attached" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

############################
# Inline policy: Bedrock InvokeModel (+ optional streaming)
############################
locals {
  bedrock_actions = concat(
    ["bedrock:InvokeModel"],
    var.allow_streaming ? ["bedrock:InvokeModelWithResponseStream"] : []
  )
}

data "aws_iam_policy_document" "titan_model" {
  statement {
    sid       = "AllowInvokeBedrockModel"
    effect    = "Allow"
    actions   = local.bedrock_actions
    resources = [var.bedrock_model_arn]
  }
}

resource "aws_iam_role_policy" "titan_model" {
  name   = "titan_model"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.titan_model.json
}

############################
# Outputs
############################
output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn  }
