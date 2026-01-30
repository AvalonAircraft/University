# Module: IAM-Lambda-S3-PDF-Worker


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


# Inputs

variable "role_name" {
  type        = string
  description = "Name der IAM Rolle für den S3 Worker"
  validation {
    condition     = length(trim(var.role_name, " ")) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "role_path"   { type = string, default = "/service-role/" }
variable "policy_arns" { type = list(string), default = [] }
variable "tags"        { type = map(string), default = {} }

variable "bucket_name" {
  type        = string
  description = "Name des Ziel-Buckets (Assets)"
  validation {
    condition     = length(trim(var.bucket_name, " ")) > 0
    error_message = "bucket_name darf nicht leer sein."
  }
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


# Inline Policy: S3 PDF Operations

data "aws_iam_policy_document" "s3_inline" {
  statement {
    sid    = "S3ObjectLifecycleAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:GetObject",
      "s3:GetObjectTagging"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "s3_inline" {
  name   = "S3WorkerPermissions"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.s3_inline.json
}


# Outputs

output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
