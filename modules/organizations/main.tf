terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.54"
    }
  }
}

############################################
# Inputs
############################################
variable "org_feature_set"   { type = string  default = "ALL" }
variable "ou_core_name"      { type = string  default = "CoreServices" }
variable "ou_tenants_name"   { type = string  default = "Tenants" }

# (Optional) neue Member-Konten
variable "tenants" {
  description = "Tenants/Konten, die erstellt werden sollen (leer = nur OUs/Policies)."
  type = list(object({
    name       = string      # Anzeigename
    email      = string      # eindeutige E-Mail
    tenant_id  = string      # z.B. tenant-001
    role_name  = optional(string, "OrganizationAccountAccessRole")
    tags       = optional(map(string), {})
    existing_account = optional(bool, false) # true => wird NICHT erstellt
  }))
  default = []
}

# Tag Policy – Pattern für TenantID
variable "tenant_id_pattern" { type = string default = "tenant-*" }

variable "common_tags"       { type = map(string) default = {} }

############################################
# Organization + OUs
############################################
resource "aws_organizations_organization" "this" {
  feature_set = var.org_feature_set
}

data "aws_organizations_organization" "current" {
  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_organizational_unit" "core" {
  name      = var.ou_core_name
  parent_id = data.aws_organizations_organization.current.roots[0].id
  tags      = var.common_tags
}

resource "aws_organizations_organizational_unit" "tenants" {
  name      = var.ou_tenants_name
  parent_id = data.aws_organizations_organization.current.roots[0].id
  tags      = var.common_tags
}

############################################
# (Optional) Tenant-Accounts anlegen
############################################
resource "aws_organizations_account" "tenant" {
  for_each  = { for t in var.tenants : t.tenant_id => t if t.existing_account != true }

  name      = each.value.name
  email     = each.value.email
  role_name = each.value.role_name

  parent_id = aws_organizations_organizational_unit.tenants.id
  tags      = merge(each.value.tags, var.common_tags, { TenantID = each.key })
}

############################################
# Tag Policy: TenantID erzwingen (Schlüssel & Pattern)
############################################
resource "aws_organizations_enable_policy_type" "tag_policy_on_root" {
  root_id     = data.aws_organizations_organization.current.roots[0].id
  policy_type = "TAG_POLICY"
}

locals {
  # Minimal gültiges Tag-Policy-Dokument
  tag_policy_json = jsonencode({
    tags = {
      TenantID = {
        tag_key   = { "@@assign" = "TenantID" }
        tag_value = { "@@pattern" = var.tenant_id_pattern }
      }
    }
  })
}

resource "aws_organizations_policy" "tag_policy" {
  name        = "TenantID_TagPolicy"
  description = "Erzwingt den Tag-Schlüssel 'TenantID' (Pattern ${var.tenant_id_pattern})."
  type        = "TAG_POLICY"
  content     = local.tag_policy_json

  depends_on = [aws_organizations_enable_policy_type.tag_policy_on_root]
}

resource "aws_organizations_policy_attachment" "tag_policy_root" {
  policy_id = aws_organizations_policy.tag_policy.id
  target_id = data.aws_organizations_organization.current.roots[0].id
}

resource "aws_organizations_policy_attachment" "tag_policy_tenants_ou" {
  policy_id = aws_organizations_policy.tag_policy.id
  target_id = aws_organizations_organizational_unit.tenants.id
}

############################################
# Outputs
############################################
output "org_id"        { value = aws_organizations_organization.this.id }
output "ou_core_id"    { value = aws_organizations_organizational_unit.core.id }
output "ou_tenants_id" { value = aws_organizations_organizational_unit.tenants.id }

output "tenant_account_ids" {
  description = "Map TenantID -> AWS Account ID (nur neu erstellte)."
  value       = { for k, v in aws_organizations_account.tenant : k => v.id }
}
