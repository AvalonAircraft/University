data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region" { type = string, default = "us-east-1" }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "IAM"
    TenantID = ""
  }
}

# Rolle
variable "role_name" { type = string, default = "agentTaskRole" }

# Inline-Policy Parameter (Default aus der eigenen Umgebung)
variable "s3_bucket_name" { type = string, default = "miraedrive-assets" }

variable "kms_key_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/mrk-3e9cc314f44947ffb7abb50e39434caa"
}

# Bedrock Model (wie in der eigenen Rolle)
variable "bedrock_model_id" { type = string, default = "anthropic.claude-3-haiku-20240307-v1:0" }

# EventBridge Bus (Standard = event-bus-miraedrive-2)
variable "event_bus_name" { type = string, default = "event-bus-miraedrive-2" }
# Optional: expliziter ARN; wenn leer, wird aus Name+Account gebaut
variable "event_bus_arn"  { type = string, default = "" }
