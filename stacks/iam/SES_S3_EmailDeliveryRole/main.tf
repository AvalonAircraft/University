module "ses_s3_email_delivery_role" {
  source               = "../../../modules/iam/ses_s3_email_delivery_role"

  role_name            = var.role_name
  role_path            = "/"
  bucket_name          = var.bucket_name
  kms_key_arn          = var.kms_key_arn
  ses_receipt_rule_arn = var.ses_receipt_rule_arn
  tags                 = var.tags
}

output "role_name" { value = module.ses_s3_email_delivery_role.role_name }
output "role_arn"  { value = module.ses_s3_email_delivery_role.role_arn  }
