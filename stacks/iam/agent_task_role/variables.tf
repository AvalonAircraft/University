# Data Sources (optional but ok)

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

variable "role_name" {
  type        = string
  description = "IAM role name for the agent task role (should be unique per account/stage)."
  default     = "agentTaskRole"
}

variable "role_path" {
  type        = string
  description = "IAM role path."
  default     = "/"
}


# S3 (MUST be provided per environment)

variable "s3_bucket_name" {
  type        = string
  description = "S3 bucket name used by the agent. Must exist or be created by another stack."
}


# KMS (portable)

variable "kms_key_arn" {
  type        = string
  description = "Optional: KMS key ARN. Leave empty to resolve by alias or to disable KMS-specific permissions."
  default     = ""
}

variable "kms_key_alias" {
  type        = string
  description = "Optional: KMS key alias to resolve ARN (e.g., alias/kms-tenant-master-key)."
  default     = ""
}


# Bedrock Model

variable "bedrock_model_id" {
  type        = string
  description = "Bedrock model id (only used for scoping permissions in policies)."
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}


# EventBridge

variable "event_bus_name" {
  type        = string
  description = "EventBridge bus name."
  default     = "event-bus-miraedrive-2"
}

variable "event_bus_arn" {
  type        = string
  description = "Optional: explicit EventBridge bus ARN. If empty, derived from name/account/region."
  default     = ""
}
