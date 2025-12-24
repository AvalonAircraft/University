############################
# Data sources (für Multi-Account/Region)
############################
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

############################
# Inputs
############################
variable "role_name" {
  description = "Name der IAM Rolle (z.B. TenantRole)"
  type        = string

  validation {
    condition     = length(trim(var.role_name)) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "role_path" {
  description = "IAM Role path"
  type        = string
  default     = "/"
}

variable "bucket" {
  description = "S3 Bucket-Name, in dem die tenant-spezifischen Prefixe liegen (z.B. miraedrive-assets)"
  type        = string

  validation {
    condition     = length(trim(var.bucket)) > 0
    error_message = "bucket darf nicht leer sein."
  }
}

# Optional: zusätzliche Principals, die die Rolle annehmen dürfen.
# Wenn leer, vertraut man standardmäßig dem Root des aktuellen Accounts.
variable "trusted_principals" {
  description = "Zusätzliche IAM-Principals (ARNs), die die Rolle annehmen dürfen. Wenn leer, wird root des aktuellen Accounts verwendet."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Zusätzliche Tags"
  type        = map(string)
  default     = {}
}

############################
# Locals
############################
locals {
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id

  # Standard-Trust: Root des aktuellen Accounts
  default_trustees = ["arn:${local.partition}:iam::${local.account_id}:root"]

  trustees = length(var.trusted_principals) > 0 ? var.trusted_principals : local.default_trustees

  # Für S3-Policy
  bucket_arn = "arn:${local.partition}:s3:::${var.bucket}"

  # WICHTIG: so bleibt ${aws:PrincipalTag/TenantID} LITERAL in der Policy
  tenant_tag_var = "$${aws:PrincipalTag/TenantID}"
}

############################
# Trust policy
############################
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.trustees
    }
  }
}

############################
# Inline-Policy: TenantRoleS3AccessPolicy
#  - S3:GetObject/PutObject auf bucket/${aws:PrincipalTag/TenantID}/*
#  - ListBucket eingeschränkt auf prefix=${aws:PrincipalTag/TenantID}/*
############################
data "aws_iam_policy_document" "tenant_s3" {
  statement {
    sid     = "S3TenantAccess"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = [
      "${local.bucket_arn}/${local.tenant_tag_var}/*"
    ]
  }

  statement {
    sid     = "ListTenantPrefix"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [local.bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.tenant_tag_var}/*"]
    }
  }
}

############################
# Role
############################
resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "tenant_policy" {
  name   = "TenantRoleS3AccessPolicy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.tenant_s3.json
}

############################
# Outputs
############################
output "role_name" {
  description = "Rollenname"
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "Rollen-ARN"
  value       = aws_iam_role.this.arn
}
