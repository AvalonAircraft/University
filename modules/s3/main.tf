data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

############################
# Inputs
############################
variable "bucket_name"                { type = string }                      # z.B. "miraedrive-assets"
variable "enable_versioning"          { type = bool,   default = true }
variable "enable_eventbridge"         { type = bool,   default = true }
variable "enable_website"             { type = bool,   default = true }
variable "website_index_document"     { type = string, default = "index.html" }
variable "website_error_document"     { type = string, default = "error.html" }

# Optional: Dev-Comfort
variable "force_destroy"              { type = bool,   default = false }

# Block Public Access (alle standardmäßig AN)
variable "block_public_acls"          { type = bool, default = true }
variable "block_public_policy"        { type = bool, default = true }
variable "ignore_public_acls"         { type = bool, default = true }
variable "restrict_public_buckets"    { type = bool, default = true }

# Bucket Policy Parameter (alle optional; Statements werden nur erzeugt, wenn Werte vorhanden sind)
variable "cloudfront_distribution_arns" {
  type    = list(string)
  default = [] # z.B. ["arn:${data.aws_partition.current.partition}:cloudfront::123456789012:distribution/E29YYY0KR07BIY","..."]
}

variable "logs_delivery_source_arn" {
  type    = string
  default = "" # arn:${partition}:logs:${region}:<acct>:delivery-source:EventBusSource-...
}
variable "logs_account_id" {
  type    = string
  default = "" # "186261963982"
}
variable "logs_prefix" {
  type    = string
  default = "AWSLogs/186261963982/EventBusLogs/*"
}

variable "ses_receipt_rule_arn" {
  type    = string
  default = "" # arn:${partition}:ses:${region}:<acct>:receipt-rule-set/xxx:receipt-rule/yyy
}
variable "ses_account_id" {
  type    = string
  default = "" # "186261963982"
}
variable "ses_prefix" {
  type    = string
  default = "emails/*"
}

variable "tenant_role_arn" {
  type    = string
  default = "" # arn:${partition}:iam::<acct>:role/TenantRole
}
variable "tenant_tag_pattern" {
  type    = string
  default = "tenant*"   # StringLike-Muster für aws:PrincipalTag/TenantID
}

variable "tags" { type = map(string), default = {} }

############################
# Validations
############################
validation {
  condition     = length(var.bucket_name) > 0
  error_message = "bucket_name darf nicht leer sein."
}
validation {
  condition     = (!var.enable_website) || (var.block_public_policy && var.block_public_acls && var.ignore_public_acls && var.restrict_public_buckets)
  error_message = "Website ist aktiviert. Dieses Modul erwartet Zugriff via CloudFront (Public Access bleibt geblockt)."
}
validation {
  condition     = var.logs_delivery_source_arn == "" ? true : can(regex("^arn:", var.logs_delivery_source_arn))
  error_message = "logs_delivery_source_arn muss eine gültige ARN sein oder leer."
}
validation {
  condition     = var.ses_receipt_rule_arn == "" ? true : can(regex("^arn:", var.ses_receipt_rule_arn))
  error_message = "ses_receipt_rule_arn muss eine gültige ARN sein oder leer."
}

############################
# Bucket
############################
resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

# Ownership (erforderlich, weil CloudWatch Logs mit ACL schreibt)
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

# Versioning
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
    # MFA Delete per API nicht steuerbar
  }
}

# Default encryption (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3
    }
    bucket_key_enabled = false # nur relevant bei SSE-KMS
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = var.block_public_acls
  ignore_public_acls      = var.ignore_public_acls
  block_public_policy     = var.block_public_policy
  restrict_public_buckets = var.restrict_public_buckets
}

# Website hosting (optional)
resource "aws_s3_bucket_website_configuration" "this" {
  count  = var.enable_website ? 1 : 0
  bucket = aws_s3_bucket.this.id

  index_document { suffix = var.website_index_document }
  error_document { key    = var.website_error_document }
}

# EventBridge notifications (für alle Ereignisse)
resource "aws_s3_bucket_notification" "this" {
  count       = var.enable_eventbridge ? 1 : 0
  bucket      = aws_s3_bucket.this.id
  eventbridge = true
}

############################
# Bucket Policy (dynamisch zusammengesetzt)
############################
locals {
  # Hilfen für Policyteile
  cf_statements = length(var.cloudfront_distribution_arns) == 0 ? [] : [
    {
      Sid      = "AllowCloudFrontServicePrincipal"
      Effect   = "Allow"
      Principal= { Service = "cloudfront.amazonaws.com" }
      Action   = "s3:GetObject"
      Resource = "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/*"
      Condition= { ArnLike = { "AWS:SourceArn" = var.cloudfront_distribution_arns } }
    }
  ]

  logs_statements = var.logs_delivery_source_arn == "" || var.logs_account_id == "" ? [] : [
    {
      Sid      = "AWSLogDeliveryWrite1"
      Effect   = "Allow"
      Principal= { Service = "delivery.logs.amazonaws.com" }
      Action   = "s3:PutObject"
      Resource = "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/${var.logs_prefix}"
      Condition= {
        StringEquals = {
          "aws:SourceAccount" = var.logs_account_id
          "s3:x-amz-acl"      = "bucket-owner-full-control"
        }
        ArnLike = { "aws:SourceArn" = var.logs_delivery_source_arn }
      }
    }
  ]

  ses_statements = var.ses_receipt_rule_arn == "" ? [] : [
    {
      Sid      = "AllowSESPutObject"
      Effect   = "Allow"
      Principal= { Service = "ses.amazonaws.com" }
      Action   = "s3:PutObject"
      Resource = "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/${var.ses_prefix}"
      Condition= {
        StringEquals = {
          "AWS:SourceArn"    = var.ses_receipt_rule_arn
          "AWS:SourceAccount"= var.ses_account_id
        }
      }
    }
  ]

  tenant_statements = var.tenant_role_arn == "" ? [] : [
    {
      Sid      = "AllowTenantScopedAccess"
      Effect   = "Allow"
      Principal= { AWS = var.tenant_role_arn }
      Action   = ["s3:GetObject","s3:PutObject"]
      Resource = format("arn:${data.aws_partition.current.partition}:s3:::%s/%s/*", var.bucket_name, "$${aws:PrincipalTag/TenantID}")
      Condition= { StringLike = { "aws:PrincipalTag/TenantID" = var.tenant_tag_pattern } }
    }
  ]

  policy_json = jsonencode({
    Version   = "2012-10-17",
    Statement = concat(local.cf_statements, local.logs_statements, local.ses_statements, local.tenant_statements)
  })
}

resource "aws_s3_bucket_policy" "this" {
  count  = length(jsondecode(local.policy_json).Statement) == 0 ? 0 : 1
  bucket = aws_s3_bucket.this.id
  policy = local.policy_json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

############################
# Outputs
############################
output "bucket_name"      { value = aws_s3_bucket.this.bucket }
output "bucket_arn"       { value = aws_s3_bucket.this.arn }
output "regional_domain"  { value = aws_s3_bucket.this.bucket_regional_domain_name }
output "website_endpoint" { value = var.enable_website ? aws_s3_bucket_website_configuration.this[0].website_endpoint : null }
