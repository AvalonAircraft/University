# Module: Organizations-Tenancy


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.54"
    }
  }
}


# Inputs


variable "org_feature_set"   { type = string,  default = "ALL" }
variable "ou_core_name"      { type = string,  default = "CoreServices" }
variable "ou_tenants_name"   { type = string,  default = "Tenants" }

variable "tenants" {
  description = "Liste der zu erstellenden Tenant-Accounts."
  type = list(object({
    name             = string
    email            = string
    tenant_id        = string
    role_name        = optional(string, "OrganizationAccountAccessRole")
    tags             = optional(map(string), {})
    existing_account = optional(bool, false)
  }))
  default = []
}

variable "tenant_id_pattern" { 
  type        = string 
  default     = "tenant-*" 
  description = "Regex-Pattern für die Validierung des TenantID Tags."
}

variable "common_tags" { type = map(string), default = {} }


# 1. Organization + OUs


resource "aws_organizations_organization" "this" {
  feature_set = var.org_feature_set
}

# Datenquelle für Root-ID Zugriff
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


# 2. Tenant Accounts


resource "aws_organizations_account" "tenant" {
  for_each  = { for t in var.tenants : t.tenant_id => t if !t.existing_account }

  name      = each.value.name
  email     = each.value.email
  role_name = each.value.role_name

  parent_id = aws_organizations_organizational_unit.tenants.id
  
  # Schließt IAM-User Zugriff auf Billing ein (standardmäßig oft aus)
  iam_user_access_to_billing = "ALLOW"

  tags = merge(
    var.common_tags,
    each.value.tags,
    { TenantID = each.key }
  )
}


# 3. Governance: Tag Policy


# Aktiviert den Policy-Typ auf der Root-Ebene
resource "aws_organizations_enable_policy_type" "tag_policy_on_root" {
  root_id     = data.aws_organizations_organization.current.roots[0].id
  policy_type = "TAG_POLICY"
}

locals {
  tag_policy_json = jsonencode({
    tags = {
      TenantID = {
        tag_key   = { "@@assign" = "TenantID" }
        tag_value = { "@@pattern" = [var.tenant_id_pattern] }
        enforced_for = { "@@assign" = ["lambda:function", "ec2:instance", "s3:bucket"] }
      }
    }
  })
}

resource "aws_organizations_policy" "tag_policy" {
  name        = "TenantID_Enforcement_Policy"
  description = "Erzwingt korrektes Tagging für Tenant-Ressourcen."
  type        = "TAG_POLICY"
  content     = local.tag_policy_json

  depends_on = [aws_organizations_enable_policy_type.tag_policy_on_root]
}

# Anwendung auf die gesamte Organization
resource "aws_organizations_policy_attachment" "tag_policy_root" {
  policy_id = aws_organizations_policy.tag_policy.id
  target_id = data.aws_organizations_organization.current.roots[0].id
}


# Outputs


output "org_id"        { value = aws_organizations_organization.this.id }
output "root_id"       { value = data.aws_organizations_organization.current.roots[0].id }
output "ou_tenants_id" { value = aws_organizations_organizational_unit.tenants.id }

output "tenant_account_ids" {
  description = "Mapping von TenantID zu AWS Account ID."
  value       = { for k, v in aws_organizations_account.tenant : k => v.id }
}
