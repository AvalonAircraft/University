provider "aws" {
  region = var.region
}

module "organizations" {
  source = "../../modules/organizations"

  org_feature_set   = "ALL"
  ou_core_name      = var.ou_core_name
  ou_tenants_name   = var.ou_tenants_name
  tenant_id_pattern = var.tenant_id_pattern

  # Beispiel
  tenants = var.tenants

  common_tags = var.tags
}

output "org_id"         { value = module.organizations.org_id }
output "ou_core_id"     { value = module.organizations.ou_core_id }
output "ou_tenants_id"  { value = module.organizations.ou_tenants_id }
output "tenant_account_ids" { value = module.organizations.tenant_account_ids }
