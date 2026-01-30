# Module: IAM-SES-S3-Delivery-Role


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
data "aws_caller_identity" "current" {}


# Inputs

variable "role_name" {
  type        = string
  description = "Name der Rolle für die SES S3-Zustellung"
  validation {
    condition     = length(trim(var.role_name, " ")) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "bucket_name" {
  type        = string
  validation {
    condition     = length(trim(var.bucket_name, " ")) > 0
    error_message = "bucket_name darf nicht leer sein."
  }
}

variable "kms_key_arn" {
  type        = string
  validation {
    # Korrektur: Backslash-Handling und Partitions-Flexibilität
    condition = can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "kms_key_arn muss eine gültige AWS KMS Key ARN sein."
  }
}

variable "ses_receipt_rule_arn" {
  type        = string
  validation {
    condition = can(regex("^arn:aws[a-z-]*:ses:[a-z0-9-]+:[0-9]{12}:receipt-rule-set/.+:receipt-rule/.+$", var.ses_receipt_rule_arn))
    error_message = "ses_receipt_rule_arn muss eine gültige SES Receipt-Rule ARN sein."
  }
}

variable "role_path" { type = string, default = "/" }
variable "tags"      { type = map(string), default = {} }


# Trust Policy (SES)

data "aws_iam_policy_document" "trust_ses" {
  statement {
    sid     = "AllowSESToAssumeForThisReceiptRule"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.ses_receipt_rule_arn]
    }
  }
}


# Inline Policy: S3 & KMS

data "aws_iam_policy_document" "inline" {
  statement {
    sid    = "AllowSESPutObject"
    effect = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/*"
    ]
  }

  statement {
    sid    = "AllowSESKMS"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey"
    ]
    resources = [var.kms_key_arn]
  }
}


# Role + Policy Link

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_ses.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "inline" {
  name   = "SES_EmailToS3_KMS_Permissions"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline.json
}


# Outputs

output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
