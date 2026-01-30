provider "aws" {
  region = var.region
}


# Account-agnostic helpers

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# Optional: resolve KMS Key ARN from alias (portable)
# If kms_key_arn is set => use it
# Else if kms_key_alias is set => lookup ARN via data source

data "aws_kms_key" "by_alias" {
  count  = (var.kms_key_arn == "" && var.kms_key_alias != "") ? 1 : 0
  key_id = var.kms_key_alias
}

locals {
  effective_kms_key_arn = coalesce(
    nullif(var.kms_key_arn, ""),
    try(data.aws_kms_key.by_alias[0].arn, null)
  )
}


# Module call

module "ses_s3_email_delivery_role" {
  source = "../../../modules/iam/ses_s3_email_delivery_role"

  role_name            = var.role_name
  role_path            = var.role_path
  bucket_name          = var.bucket_name
  kms_key_arn          = local.effective_kms_key_arn
  ses_receipt_rule_arn = var.ses_receipt_rule_arn
  tags                 = var.tags
}


# Outputs

output "role_name" {
  value = module.ses_s3_email_delivery_role.role_name
}

output "role_arn" {
  value = module.ses_s3_email_delivery_role.role_arn
}
