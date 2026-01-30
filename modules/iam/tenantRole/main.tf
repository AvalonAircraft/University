# Module: IAM-MultiTenant-ABAC-Role


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}


# Data Sources

data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}


# Inputs

variable "role_name" {
  type        = string
  description = "Name der IAM Rolle (z.B. MiraeDrive-Tenant-Role)"
  validation {
    condition     = length(trim(var.role_name, " ")) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "role_path" {
  type    = string
  default = "/"
}

variable "bucket" {
  type        = string
  description = "S3 Bucket-Name für die Mandantendaten"
  validation {
    condition     = length(trim(var.bucket, " ")) > 0
    error_message = "bucket darf nicht leer sein."
  }
}

variable "trusted_principals" {
  type        = list(string)
  default     = []
  description = "Optionale Liste von ARNs, die die Rolle annehmen dürfen. Standard: Root des Accounts."
}

variable "tags" {
  type    = map(string)
  default = {}
}


# Locals

locals {
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
  
  # Wenn keine Principals angegeben sind, vertraue dem eigenen Account (Root)
  trustees = length(var.trusted_principals) > 0 ? var.trusted_principals : ["arn:${local.partition}:iam::${local.account_id}:root"]

  bucket_arn = "arn:${local.partition}:s3:::${var.bucket}"

  # Verhindert, dass Terraform das $${...} als eigene Variable interpoliert
  # AWS liest dies später als: ${aws:PrincipalTag/TenantID}
  tenant_tag_context = "$${aws:PrincipalTag/TenantID}"
}


# Trust Policy (mit ABAC-Enforcement)

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowAssumeWithTenantContext"
    effect  = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession" # Notwendig, um PrincipalTags an die Session zu binden
    ]

    principals {
      type        = "AWS"
      identifiers = local.trustees
    }

    # Sicherheit: Rolle kann nur genutzt werden, wenn eine TenantID im Kontext existiert
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalTag/TenantID"
      values   = ["*"]
    }
  }
}


# Inline-Policy: Dynamische S3-Isolierung

data "aws_iam_policy_document" "tenant_s3" {
  # Zugriff auf die Objekte innerhalb des Tenant-Prefix
  statement {
    sid    = "S3TenantObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject" # Optional, falls Löschen erlaubt sein soll
    ]
    resources = [
      "${local.bucket_arn}/${local.tenant_tag_context}/*"
    ]
  }

  # Erlaubt das Auflisten des Buckets, aber NUR für den eigenen Prefix
  statement {
    sid    = "ListTenantPrefixOnly"
    effect = "Allow"
    actions = ["s3:ListBucket"]
    resources = [local.bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.tenant_tag_context}/*"]
    }
  }
}


# Resource Creation

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "tenant_policy" {
  name   = "TenantIsolationPolicy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.tenant_s3.json
}


# Outputs

output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
