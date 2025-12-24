module "ecr_kms" {
  source = "../../../modules/kms/ecr-key"

  alias_name          = var.alias_name
  description         = var.description
  enable_multi_region = var.enable_multi_region
  repository_arn      = var.repository_arn
  tags                = var.tags
}

output "ecr_key_arn"   { value = module.ecr_kms.key_arn }
output "ecr_alias_arn" { value = module.ecr_kms.alias_arn }
