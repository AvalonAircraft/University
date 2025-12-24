############################
# Provider
############################
provider "aws" {
  region = var.region
}

############################
# Modul: TenantRole
############################
module "tenant_role" {
  source = "../../../modules/iam/tenantRole"

  role_name          = var.role_name
  role_path          = "/"
  bucket             = var.bucket
  trusted_principals = var.trusted_principals
  tags               = var.tags
}

############################
# Outputs
############################
output "tenant_role_name" {
  value = module.tenant_role.role_name
}

output "tenant_role_arn" {
  value = module.tenant_role.role_arn
}
