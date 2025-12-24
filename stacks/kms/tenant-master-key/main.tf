module "tenant_master_kms" {
  source = "../../../modules/kms/tenant-master-key"

  alias_name               = var.alias_name
  description              = var.description
  enable_multi_region      = var.enable_multi_region
  admin_role_arn           = var.admin_role_arn
  tenant_role_name         = var.tenant_role_name
  allow_tenant_tag_pattern = var.allow_tenant_tag_pattern

  attach_ses_statement = var.attach_ses_statement
  ses_receipt_rule_arn = var.ses_receipt_rule_arn

  tags = var.tags
}

output "tenant_master_key_arn"   { value = module.tenant_master_kms.key_arn }
output "tenant_master_alias_arn" { value = module.tenant_master_kms.alias_arn }
