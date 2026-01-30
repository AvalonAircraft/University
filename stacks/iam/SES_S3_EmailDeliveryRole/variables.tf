# stacks/iam/ses_s3_email_delivery_role/variables.tf

variable "region" {
  description = "AWS Region (provider uses this)."
  type        = string
  default     = "us-east-1"
}

variable "role_name" {
  description = "IAM role name for SES -> S3 email delivery."
  type        = string
  default     = "SES_S3_EmailDeliveryRole"
}

variable "role_path" {
  description = "IAM role path."
  type        = string
  default     = "/"
}

variable "bucket_name" {
  description = "S3 bucket name where SES stores inbound emails."
  type        = string
}

# Optional: allow either ARN or alias (portable)
variable "kms_key_arn" {
  description = "Optional: KMS key ARN for S3 object encryption. Leave empty if not used."
  type        = string
  default     = ""
}

variable "kms_key_alias" {
  description = "Optional: KMS key alias (e.g. alias/kms-tenant-master-key). Used if kms_key_arn is empty."
  type        = string
  default     = ""
}

variable "ses_receipt_rule_arn" {
  description = "Optional: SES receipt rule ARN (only needed if your IAM policy conditions require SourceArn)."
  type        = string
  default     = ""
}

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID        = ""
  }
}
