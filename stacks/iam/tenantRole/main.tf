# Provider

provider "aws" {
  region = var.region
}


# Account-agnostic helper

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # Wenn nichts übergeben wird, vertraue Root des aktuellen Accounts (portabel).
  effective_trusted_principals = length(var.trusted_principals) > 0 ? var.trusted_principals : [
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
}


# Modul: TenantRole

module "tenant_role" {
  source = "../../../modules/iam/tenantRole"

  role_name          = var.role_name
  role_path          = var.role_path
  bucket             = var.bucket
  trusted_principals = local.effective_trusted_principals
  tags               = var.tags
}


# Outputs

output "tenant_role_name" {
  value = module.tenant_role.role_name
}

output "tenant_role_arn" {
  value = module.tenant_role.role_arn
}
