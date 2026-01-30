# Module: IAM-Lambda-RDS-Data-Worker


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}


# Inputs

variable "role_name" {
  type = string
  validation {
    condition     = length(trim(var.role_name, " ")) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "role_path"   { type = string, default = "/service-role/" }
variable "policy_arns" { type = list(string), default = [] }
variable "tags"        { type = map(string), default = {} }

variable "s3_bucket" {
  type = string
  validation {
    condition     = length(trim(var.s3_bucket, " ")) > 0
    error_message = "s3_bucket darf nicht leer sein."
  }
}

variable "kms_key_arn" {
  type = string
  validation {
    condition     = startswith(var.kms_key_arn, "arn:")
    error_message = "kms_key_arn muss eine gültige ARN sein."
  }
}

# RDS IAM Auth Parameter
variable "rds_db_users" {
  description = "Option A: Volle rds-db:connect ARNs."
  type        = list(string)
  default     = []
}

variable "rds_cluster_resource_id" {
  description = "Option B: Resource ID (cluster-XXXX). Nötig, wenn rds_db_users leer."
  type        = string
  default     = ""
}

variable "rds_db_usernames" {
  description = "Option B: DB-Usernamen. Nötig, wenn rds_db_users leer."
  type        = list(string)
  default     = []
}


# RDS Logic

locals {
  # Dynamische Erstellung der Connect-ARNs für IAM Database Authentication
  computed_rds_db_users = length(var.rds_db_users) > 0 ? var.rds_db_users : [
    for u in var.rds_db_usernames :
    "arn:${data.aws_partition.current.partition}:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${var.rds_cluster_resource_id}/${u}"
  ]
}


# Role & Trust

data "aws_iam_policy_document" "trust_lambda" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_lambda.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "attached" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}


# Inline Policy

data "aws_iam_policy_document" "inline_lambda" {
  # 1. IAM Database Authentication
  statement {
    sid       = "RdsDbConnect"
    effect    = "Allow"
    actions   = ["rds-db:connect"]
    resources = local.computed_rds_db_users
  }

  # 2. S3 Access (Daten lesen/schreiben)
  statement {
    sid    = "S3ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket}/*"
    ]
  }

  # 3. KMS (Verschlüsselung für S3)
  statement {
    sid    = "KmsS3Security"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }

  # 4. Logs (Standard-Berechtigungen)
  statement {
    sid    = "Logging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "inline_lambda" {
  name   = "LambdaDataGatewayPolicy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline_lambda.json
}


# Outputs

output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
