data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region"      { type = string, default = "us-east-1" }
variable "bucket_name" { type = string, default = "miraedrive-assets" }

# Flags
variable "enable_versioning"  { type = bool, default = true }
variable "enable_eventbridge" { type = bool, default = true }
variable "enable_website"     { type = bool, default = true }

variable "website_index_document" { type = string, default = "index.html" }
variable "website_error_document" { type = string, default = "error.html" }

# Optional (nur Dev/Tests)
variable "force_destroy" { type = bool, default = false }

# Block Public Access
variable "block_public_acls"       { type = bool, default = true }
variable "block_public_policy"     { type = bool, default = true }
variable "ignore_public_acls"      { type = bool, default = true }
variable "restrict_public_buckets" { type = bool, default = true }

# Policy-Parameter (aus deiner Beschreibung)
variable "cloudfront_distribution_arns" {
  type = list(string)
  default = [
    "arn:${data.aws_partition.current.partition}:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/E29YYY0KR07BIY",
    "arn:${data.aws_partition.current.partition}:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/E21WVRPFTZ0XEU"
  ]
}

variable "logs_delivery_source_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:delivery-source:EventBusSource-event-bus-miraedrive-ERROR_LOGS"
}
variable "logs_account_id" { type = string, default = "186261963982" }
variable "logs_prefix"     { type = string, default = "AWSLogs/186261963982/EventBusLogs/*" }

variable "ses_receipt_rule_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:receipt-rule-set/aiagent-receive:receipt-rule/analyze_incoming_email"
}
variable "ses_account_id" { type = string, default = "186261963982" }
variable "ses_prefix"     { type = string, default = "emails/*" }

variable "tenant_role_arn"    { type = string, default = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/TenantRole" }
variable "tenant_tag_pattern" { type = string, default = "tenant*" }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "S3"
    TenantID = ""
  }
}
