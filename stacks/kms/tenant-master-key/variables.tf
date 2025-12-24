variable "region" {
  description = "AWS-Region (z.B. us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "alias_name" {
  description = "Alias ohne 'alias/', z.B. 'kms-tenant-master-key'"
  type        = string
  default     = "kms-tenant-master-key"
}

variable "description" {
  description = "Beschreibung des Keys"
  type        = string
  default     = "Key fuer alle tenants"
}

variable "enable_multi_region" {
  description = "Multi-Region-Key?"
  type        = bool
  default     = true
}

variable "admin_role_arn" {
  description = "Optionale Admin-Rolle (SSO/Identity Center) mit vollen Key-Admin-Rechten"
  type        = string
  default     = ""
}

variable "tenant_role_name" {
  description = "Name der Tenant-Rolle im Account"
  type        = string
  default     = "TenantRole"
}

variable "allow_tenant_tag_pattern" {
  description = "Pattern für aws:PrincipalTag/TenantID"
  type        = string
  default     = "tenant*"
}

variable "attach_ses_statement" {
  description = "SES-Nutzung des Keys erlauben?"
  type        = bool
  default     = false
}

variable "ses_receipt_rule_arn" {
  description = "Optional: SES Receipt-Rule ARN für Condition AWS:SourceArn"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Zusätzliche Tags"
  type        = map(string)
  default = {
    Projekt   = "MiraeDrive"
    Umgebung  = "Produktiv"
    Component = "kms-tenant-master-key"
    TenantID = ""
  }
}
