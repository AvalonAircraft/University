# Module: IAM-Lambda-Bedrock-Inference


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

data "aws_partition" "current" {}
data "aws_region"    "current" {}


# Inputs

variable "role_name" {
  type        = string
  description = "Name der IAM Rolle für die Bedrock-Lambda"
  validation {
    condition     = length(trim(var.role_name, " ")) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "role_path"   { type = string, default = "/service-role/" }
variable "policy_arns" { type = list(string), default = [] }
variable "tags"        { type = map(string), default = {} }

variable "bedrock_model_arn" {
  type        = string
  description = "Die vollständige ARN des Bedrock Foundation Models"
}

variable "allow_streaming" {
  type        = bool
  default     = false
  description = "Aktiviert 'bedrock:InvokeModelWithResponseStream'"
}


# Trust Policy (Lambda)

data "aws_iam_policy_document" "trust_lambda" {
  statement {
    effect = "Allow"
    principals { 
      type        = "Service" 
      identifiers = ["lambda.amazonaws.com"] 
    }
    actions = ["sts:AssumeRole"]
  }
}


# IAM Role

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_lambda.json
  tags               = var.tags
}


# Managed Policy Attachments

resource "aws_iam_role_policy_attachment" "attached" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}


# Inline Policy: Bedrock Access

data "aws_iam_policy_document" "bedrock_invocation" {
  statement {
    sid    = "AllowInvokeBedrockModel"
    effect = "Allow"
    actions = compact([
      "bedrock:InvokeModel",
      var.allow_streaming ? "bedrock:InvokeModelWithResponseStream" : ""
    ])
    resources = [var.bedrock_model_arn]
  }
}

resource "aws_iam_role_policy" "bedrock_invocation" {
  name   = "BedrockModelAccess"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.bedrock_invocation.json
}


# Outputs

output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
