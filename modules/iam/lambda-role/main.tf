# Module: IAM-Lambda-S3-SFN-Router


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
data "aws_region" "current" {}


# Inputs

variable "role_name" {
  type = string
  validation {
    condition     = length(trim(var.role_name, " ")) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "role_path"   { type = string, default = "/service-role/" }
variable "tags"        { type = map(string), default = {} }
variable "bucket_name" { type = string }
variable "kms_key_arn" { type = string }
variable "lambda6_arn" { type = string }
variable "stepfn_arn"  { type = string }


# Trust Policy

data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}


# Role

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}


# Managed Policy Attachments

# Deckt Basic Logging ab
resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Deckt VPC-Konnektivität ab (ENI Management)
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


# Inline Policy: S3, KMS & Cross-Invoke

data "aws_iam_policy_document" "integrated_access" {
  # S3 Access (Listen auf Bucket, CRUD auf Objekten)
  statement {
    sid    = "S3DataOperations"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/*"
    ]
  }

  # KMS (Vollständiger Satz für verschlüsselte S3-Buckets)
  statement {
    sid    = "KmsS3Security"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }

  # Trigger Step Functions
  statement {
    sid       = "StartStepFlow"
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [var.stepfn_arn]
  }

  # Invoke Hilfs-Lambda (Lambda6)
  statement {
    sid       = "InvokeHelperLambda"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [var.lambda6_arn]
  }
}

resource "aws_iam_role_policy" "integrated_access" {
  name   = "Lambda-Integrated-Access"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.integrated_access.json
}


# Outputs

output "role_arn"  { value = aws_iam_role.this.arn }
output "role_name" { value = aws_iam_role.this.name }
