############################
# Module: kms/ecr-key
############################


############################
# Inputs
############################
variable "alias_name" {
  description = "KMS Alias (ohne 'alias/'), z.B. 'ECR_Key'"
  type        = string
}

variable "description" {
  description = "Beschreibung des Keys"
  type        = string
  default     = "ECR repository encryption key"
}

variable "repository_arn" {
  description = "ARN des ECR-Repositories, z.B. arn:aws:ecr:us-east-1:123456789012:repository/tenant1/hr-agent"
  type        = string
}

variable "enable_multi_region" {
  description = "Multi-Region-Key aktivieren?"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Zusätzliche Tags"
  type        = map(string)
  default     = {}
}

############################
# Data
############################
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}
data "aws_partition"       "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition

  # Für kms:ViaService – inkl. China/Gov mit dns_suffix
  dns_suffix = data.aws_partition.current.dns_suffix
  via_service = "ecr.${local.region}.${local.dns_suffix}"   # z.B. ecr.us-east-1.amazonaws.com

  # Service Principal dynamisch (aws -> ecr.amazonaws.com, aws-cn -> ecr.amazonaws.com.cn, ...)
  ecr_service_principal = "ecr.${local.dns_suffix}"
}

############################
# Validations
############################
variable "alias_name" {
  description = "KMS Alias (ohne 'alias/'), z.B. 'ECR_Key'"
  type        = string

  validation {
    condition     = length(var.alias_name) > 0 && !can(regex("^alias/", var.alias_name))
    error_message = "Bitte nur den reinen Alias ohne 'alias/' angeben (z.B. 'ECR_Key')."
  }
}


variable "repository_arn" {
  description = "ARN des ECR-Repositories, z.B. arn:aws:ecr:us-east-1:123456789012:repository/tenant1/hr-agent"
  type        = string

  validation {
    condition     = can(regex("^arn:${local.partition}:ecr:${local.region}:[0-9]{12}:repository/.+", var.repository_arn))
    error_message = "repository_arn muss ein gültiger ECR Repository ARN in der aktuellen Partition/Region sein."
  }
}


############################
# Key Policy (ECR-narrow)
############################
data "aws_iam_policy_document" "this" {
  # Root permissions
  statement {
    sid     = "EnableIAMUserPermissions"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
    resources = ["*"]
  }

  # ECR Describe Key
  statement {
    sid     = "AllowECRDescribeKey"
    effect  = "Allow"
    actions = ["kms:DescribeKey"]
    principals {
      type        = "Service"
      identifiers = [local.ecr_service_principal]   # ecr.amazonaws.com / ecr.amazonaws.com.cn
    }
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  # ECR Grant Ops
  statement {
    sid     = "AllowECRGrantOps"
    effect  = "Allow"
    actions = ["kms:CreateGrant","kms:RetireGrant"]
    principals {
      type        = "Service"
      identifiers = [local.ecr_service_principal]
    }
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = [local.via_service]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # ECR Crypto – eng auf ein bestimmtes Repository (Encryption Context bindet das Repo)
  statement {
    sid     = "AllowECRCryptoForRepo"
    effect  = "Allow"
    actions = ["kms:Encrypt","kms:Decrypt","kms:GenerateDataKey*"]
    principals {
      type        = "Service"
      identifiers = [local.ecr_service_principal]
    }
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = [local.via_service]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:ecr:arn"
      values   = [var.repository_arn]
    }
  }
}

############################
# KMS Key + Alias
############################
resource "aws_kms_key" "this" {
  description         = var.description
  multi_region        = var.enable_multi_region
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.this.json

  tags = merge(var.tags, {
    Name  = var.alias_name
    Scope = "ecr-key"
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.this.key_id
}

############################
# Outputs
############################
output "key_id"     { value = aws_kms_key.this.key_id }
output "key_arn"    { value = aws_kms_key.this.arn }
output "alias_arn"  { value = aws_kms_alias.this.arn }
output "alias_name" { value = aws_kms_alias.this.name }
