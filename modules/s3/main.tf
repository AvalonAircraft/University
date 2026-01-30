# Module: S3-Universal-Assets


data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}


# Inputs


variable "bucket_name"            { type = string }
variable "enable_versioning"      { type = bool,   default = true }
variable "enable_eventbridge"     { type = bool,   default = true }
variable "enable_website"         { type = bool,   default = false } # Meist via CloudFront
variable "website_index_document" { type = string, default = "index.html" }
variable "website_error_document" { type = string, default = "error.html" }

variable "force_destroy"          { type = bool,   default = false }

# Block Public Access (Sicherheit geht vor)
variable "block_public_acls"       { type = bool, default = true }
variable "block_public_policy"     { type = bool, default = true }
variable "ignore_public_acls"      { type = bool, default = true }
variable "restrict_public_buckets" { type = bool, default = true }

# --- Policy Parameter ---
variable "cloudfront_distribution_arns" { type = list(string), default = [] }

variable "logs_delivery_source_arn"     { type = string, default = "" }
variable "logs_account_id"              { type = string, default = "" }
variable "logs_prefix"                  { type = string, default = "AWSLogs/" }

variable "ses_receipt_rule_arn"         { type = string, default = "" }
variable "ses_account_id"               { type = string, default = "" }
variable "ses_prefix"                   { type = string, default = "emails/" }

variable "tenant_role_arn"              { type = string, default = "" }
variable "tenant_tag_pattern"           { type = string, default = "tenant*" }

variable "tags" { type = map(string), default = {} }


# Resources


resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

# Ownership (Wichtig für Cross-Account Logs & ACL-Kompatibilität)
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = var.block_public_acls
  ignore_public_acls      = var.ignore_public_acls
  block_public_policy     = var.block_public_policy
  restrict_public_buckets = var.restrict_public_buckets
}

resource "aws_s3_bucket_website_configuration" "this" {
  count  = var.enable_website ? 1 : 0
  bucket = aws_s3_bucket.this.id
  index_document { suffix = var.website_index_document }
  error_document { key    = var.website_error_document }
}

resource "aws_s3_bucket_notification" "this" {
  count       = var.enable_eventbridge ? 1 : 0
  bucket      = aws_s3_bucket.this.id
  eventbridge = true
}


# Dynamic Policy Generation


locals {
  # CloudFront OAC Statement
  cf_stmt = length(var.cloudfront_distribution_arns) == 0 ? [] : [{
    Sid       = "AllowCloudFrontOAC"
    Effect    = "Allow"
    Principal = { Service = "cloudfront.amazonaws.com" }
    Action    = "s3:GetObject"
    Resource  = "${aws_s3_bucket.this.arn}/*"
    Condition = { ArnLike = { "AWS:SourceArn" = var.cloudfront_distribution_arns } }
  }]

  # Log Delivery Statement (z.B. für CloudTrail/ALB Logs)
  logs_stmt = var.logs_delivery_source_arn == "" ? [] : [{
    Sid       = "AWSLogDeliveryWrite"
    Effect    = "Allow"
    Principal = { Service = "delivery.logs.amazonaws.com" }
    Action    = "s3:PutObject"
    Resource  = "${aws_s3_bucket.this.arn}/${var.logs_prefix}*"
    Condition = {
      StringEquals = { 
        "aws:SourceAccount" = var.logs_account_id
        "s3:x-amz-acl"      = "bucket-owner-full-control"
      }
      ArnLike = { "aws:SourceArn" = var.logs_delivery_source_arn }
    }
  }]

  # SES Receipt Statement
  ses_stmt = var.ses_receipt_rule_arn == "" ? [] : [{
    Sid       = "AllowSESPutObject"
    Effect    = "Allow"
    Principal = { Service = "ses.amazonaws.com" }
    Action    = "s3:PutObject"
    Resource  = "${aws_s3_bucket.this.arn}/${var.ses_prefix}*"
    Condition = {
      StringEquals = {
        "AWS:SourceArn"     = var.ses_receipt_rule_arn
        "AWS:SourceAccount" = var.ses_account_id
      }
    }
  }]

  # Tenant Isolation Statement (MiraeDrive Core Feature)
  tenant_stmt = var.tenant_role_arn == "" ? [] : [{
    Sid       = "TenantScopedAccess"
    Effect    = "Allow"
    Principal = { AWS = var.tenant_role_arn }
    Action    = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    Resource  = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/$${aws:PrincipalTag/TenantID}/*"
    ]
    Condition = { StringLike = { "aws:PrincipalTag/TenantID" = var.tenant_tag_pattern } }
  }]

  full_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = concat(local.cf_stmt, local.logs_stmt, local.ses_stmt, local.tenant_stmt)
  })
}

resource "aws_s3_bucket_policy" "this" {
  # Nur erstellen, wenn mindestens ein Statement vorhanden ist
  count  = length(concat(local.cf_stmt, local.logs_stmt, local.ses_stmt, local.tenant_stmt)) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = local.full_policy

  depends_on = [aws_s3_bucket_public_access_block.this]
}


# Outputs


output "bucket_name"      { value = aws_s3_bucket.this.bucket }
output "bucket_arn"       { value = aws_s3_bucket.this.arn }
output "website_endpoint" { value = var.enable_website ? aws_s3_bucket_website_configuration.this[0].website_endpoint : null }
