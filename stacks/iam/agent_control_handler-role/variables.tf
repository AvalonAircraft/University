# Data Sources

data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}


# Region

variable "region" {
  type    = string
  default = "us-east-1"
}


# Tags

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "IAM"
    TenantID        = ""
  }
}


# Role Settings

# Besser: required oder eindeutig suffixen
variable "role_name" {
  type        = string
  description = "IAM role name for the Agent Control Handler (should be unique per account/stage)."
  default     = "AgentControlHandler-role"
}


# Ressourcen

# Bucket-Name MUSS übergeben werden (andere Accounts haben andere Namen)
variable "s3_bucket_name" {
  type        = string
  description = "S3 bucket name used by the Agent Control Handler (must exist or be created by another stack)."
}


# KMS (portable)

# Optional: direkt ARN übergeben (wenn bekannt)
variable "kms_key_arn" {
  type        = string
  description = "Optional: KMS key ARN. Leave empty to resolve by alias or disable KMS-specific permissions in the module."
  default     = ""
}

# Optional: Alias statt ARN (empfohlen für Portabilität), z.B. alias/kms-tenant-master-key
variable "kms_key_alias" {
  type        = string
  description = "Optional: KMS key alias to resolve ARN (e.g., alias/kms-tenant-master-key)."
  default     = ""
}


# Managed Policy

# Wenn dein Modul eine customer managed policy erstellt: nimm einen eigenen Namen
variable "managed_policy_name" {
  type        = string
  description = "Name for the customer-managed IAM policy created/attached by the module."
  default     = "AgentControlHandlerBasicLogs"
}

# Optional (besser): AWS managed policy ARN als Input, falls Modul Attach unterstützt
# (Nur verwenden, wenn du das Modul entsprechend anpasst)
variable "managed_policy_arn" {
  type        = string
  description = "Optional: existing managed policy ARN to attach (e.g., AWSLambdaBasicExecutionRole)."
  default     = ""
}
