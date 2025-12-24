############################
# Data Sources
############################
data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

############################
# Region
############################
variable "region" {
  type    = string
  default = "us-east-1"
}

############################
# Tags
############################
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

############################
# Role Settings
############################
# Rollennamen (Terraform erstellt exakt diesen Namen)
variable "role_name" {
  type    = string
  default = "AgentControlHandler-role"
}

############################
# Ressourcen
############################
variable "s3_bucket_name" {
  type    = string
  default = "miraedrive-assets"
}

variable "kms_key_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/mrk-3e9cc314f44947ffb7abb50e39434caa"
}

############################
# Managed Policy
############################
# Kundenverwaltete Basic-Logs-Policy (Name frei wählbar)
variable "managed_policy_name" {
  type    = string
  default = "AWSLambdaBasicExecutionRole"
}
