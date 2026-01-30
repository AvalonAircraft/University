variable "region" {
  type    = string
  default = "us-east-1"
}

# IMPORTANT:
# Identity Center ist typischerweise "admin-only" und nicht in jedem Account/Setup verfügbar.
# Deshalb default = false, damit Professor-Deploy NICHT abbricht.
variable "enable_identity_center" {
  type        = bool
  description = "If false, this stack becomes a no-op (recommended default for portability)."
  default     = false
}

# Niemals hardcoden. Leer = current caller account (wird in main.tf per aws_caller_identity aufgelöst).
variable "account_id" {
  type        = string
  description = "Target AWS account id. If empty, uses the current caller account id."
  default     = ""
}


# adminUser (optional)

variable "admin_user_username" {
  type        = string
  description = "Username for the Identity Center admin user (optional)."
  default     = ""
}

variable "admin_user_email" {
  type        = string
  description = "Email for the Identity Center admin user (optional)."
  default     = ""
}

variable "admin_user_given_name" {
  type        = string
  description = "Given name for the Identity Center admin user (optional)."
  default     = ""
}

variable "admin_user_family_name" {
  type        = string
  description = "Family name for the Identity Center admin user (optional)."
  default     = ""
}

variable "admin_user_display_name" {
  type        = string
  description = "Display name for the Identity Center admin user (optional)."
  default     = ""
}


# ECRPushMinimal user (optional)

variable "ecr_user_username" {
  type        = string
  description = "Username for the Identity Center ECR push user (optional)."
  default     = ""
}

variable "ecr_user_email" {
  type        = string
  description = "Email for the Identity Center ECR push user (optional)."
  default     = ""
}

variable "ecr_user_given_name" {
  type        = string
  description = "Given name for the Identity Center ECR push user (optional)."
  default     = ""
}

variable "ecr_user_family_name" {
  type        = string
  description = "Family name for the Identity Center ECR push user (optional)."
  default     = ""
}

variable "ecr_user_display_name" {
  type        = string
  description = "Display name for the Identity Center ECR push user (optional)."
  default     = ""
}


# Groups (optional)

variable "group_admin_name" {
  type        = string
  description = "Identity Center admin group name (optional)."
  default     = ""
}

variable "group_devs_name" {
  type        = string
  description = "Identity Center devs group name (optional)."
  default     = ""
}


# Guards: wenn enabled, dann nicht "leer" deployen

locals {
  has_any_user = (
    length(trim(var.admin_user_username)) > 0 ||
    length(trim(var.ecr_user_username)) > 0
  )
  has_any_group = (
    length(trim(var.group_admin_name)) > 0 ||
    length(trim(var.group_devs_name)) > 0
  )
}

# Dummy variable nur für validation (Terraform hat kein assert)
variable "validation_guard" {
  type    = string
  default = "ok"

  validation {
    condition = (
      var.enable_identity_center == false ||
      local.has_any_user || local.has_any_group
    )
    error_message = "enable_identity_center=true requires at least one user or group input."
  }
}
