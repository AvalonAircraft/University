############################
# Module: kms/tenant-master-key
############################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30.0"
    }
  }
}

############################
# Inputs
############################
variable "alias_name" {
  description = "KMS Alias (ohne 'alias/'), z.B. 'kms-tenant-master-key'"
  type        = string
}

variable "description" {
  description = "Beschreibung des Keys"
  type        = string
  default     = "Tenant master key (multi-tenant data encryption)"
}

variable "enable_multi_region" {
  description = "Multi-Region-Key aktivieren?"
  type        = bool
  default     = true
}

variable "admin_role_arn" {
  description = "Optionale Admin-Rolle (SSO/CIAM etc.) mit vollen Key-Admin-Rechten"
  type        = string
  default     = ""
}

variable "tenant_role_name" {
  description = "Name der Tenant-Rolle im Account (ohne ARN)"
  type        = string
  default     = "TenantRole"
}

variable "allow_tenant_tag_pattern" {
  description = "Erlaubtes Pattern für aws:PrincipalTag/TenantID"
  type        = string
  default     = "tenant*"
}

variable "attach_ses_statement" {
  description = "SES-Nutzung des Keys erlauben?"
  type        = bool
  default     = false
}

variable "ses_receipt_rule_arn" {
  description = "Optionale SES Receipt-Rule ARN (nur wenn attach_ses_statement = true)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Zusätzliche Tags"
  type        = map(string)
  default     = {}
}

############################
# Environment
############################
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}
data "aws_partition"       "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  partition   = data.aws_partition.current.partition

  tenant_role_arn = "arn:${local.partition}:iam::${local.account_id}:role/${var.tenant_role_name}"

  admin_statement = var.admin_role_arn != "" ? [{
    sid     = "Allow access for Key Administrators"
    actions = [
      "kms:Encrypt","kms:Decrypt","kms:GenerateDataKey","kms:DescribeKey",
      "kms:Create*","kms:Describe*","kms:Enable*","kms:List*","kms:Put*",
      "kms:Update*","kms:Revoke*","kms:Disable*","kms:Get*","kms:Delete*",
      "kms:TagResource","kms:UntagResource","kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion","kms:ReplicateKey","kms:UpdatePrimaryRegion","kms:RotateKeyOnDemand"
    ]
    principals = [{ type = "AWS", identifiers = [var.admin_role_arn] }]
  }] : []

  ses_statement = var.attach_ses_statement ? [{
    sid        = "AllowSESUse"
    actions    = ["kms:Encrypt","kms:GenerateDataKey"]
    principals = [{ type = "Service", identifiers = ["ses.amazonaws.com"] }]
  }] : []
}

############################
# Validations
############################
validation {
  condition     = length(var.alias_name) > 0 && !can(regex("^alias/", var.alias_name))
  error_message = "Bitte nur den reinen Alias ohne 'alias/' angeben (z.B. 'kms-tenant-master-key')."
}

############################
# Key Policy
############################
data "aws_iam_policy_document" "this" {
  # Root
  statement {
    sid     = "Enable IAM User Permissions"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
    resources = ["*"]
  }

  # Optional Admin
  dynamic "statement" {
    for_each = local.admin_statement
    content {
      sid     = statement.value.sid
      effect  = "Allow"
      actions = statement.value.actions
      principals {
        type        = statement.value.principals[0].type
        identifiers = statement.value.principals[0].identifiers
      }
      resources = ["*"]
    }
  }

  # SES (optional, streng auf SourceAccount + optional SourceArn)
  dynamic "statement" {
    for_each = local.ses_statement
    content {
      sid     = statement.value.sid
      effect  = "Allow"
      actions = statement.value.actions
      principals {
        type        = statement.value.principals[0].type
        identifiers = statement.value.principals[0].identifiers
      }
      resources = ["*"]

      condition {
        test     = "StringEquals"
        variable = "AWS:SourceAccount"
        values   = [local.account_id]
      }

      dynamic "condition" {
        for_each = var.ses_receipt_rule_arn != "" ? [1] : []
        content {
          test     = "StringEquals"
          variable = "AWS:SourceArn"
          values   = [var.ses_receipt_rule_arn]
        }
      }
    }
  }

  # TenantRole (tag-gebunden)
  statement {
    sid     = "AllowTenantAccess"
    effect  = "Allow"
    actions = ["kms:Encrypt","kms:Decrypt","kms:GenerateDataKey","kms:DescribeKey"]
    principals {
      type        = "AWS"
      identifiers = [local.tenant_role_arn]
    }
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalTag/TenantID"
      values   = [var.allow_tenant_tag_pattern]
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
    Scope = "tenant-master-key"
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
