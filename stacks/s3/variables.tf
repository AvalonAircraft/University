data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region" {
  type    = string
  default = "us-east-1"
}


# REQUIRED: Bucket name must be provided
# (S3 names are global unique)

variable "bucket_name" {
  type        = string
  description = "Globally-unique bucket name. Do NOT hardcode a shared name. Provide via terraform.tfvars."
}


# Flags

variable "enable_versioning" {
  type    = bool
  default = true
}

variable "enable_eventbridge" {
  type    = bool
  default = true
}

variable "enable_website" {
  type    = bool
  default = false
  description = "If true, creates S3 static website hosting config. Note: website endpoints are HTTP-only."
}

variable "website_index_document" {
  type    = string
  default = "index.html"
}

variable "website_error_document" {
  type    = string
  default = "error.html"
}


# Optional (Dev/Tests)

variable "force_destroy" {
  type        = bool
  default     = false
  description = "If true, allows bucket destroy even when objects exist (Dev only)."
}


# Block Public Access (safe defaults)

variable "block_public_acls" {
  type    = bool
  default = true
}
variable "block_public_policy" {
  type    = bool
  default = true
}
variable "ignore_public_acls" {
  type    = bool
  default = true
}
variable "restrict_public_buckets" {
  type    = bool
  default = true
}


# OPTIONAL policy parameters
# Keep all of these neutral by default.
# The module must guard on empty values (count/for_each).


# CloudFront distributions allowed to read the bucket (optional)
variable "cloudfront_distribution_arns" {
  type        = list(string)
  default     = []
  description = "Optional: list of CloudFront distribution ARNs allowed in bucket policy. Empty disables CF policy."
}

# CloudWatch Logs delivery source -> S3 delivery destination (optional)
variable "logs_delivery_source_arn" {
  type        = string
  default     = ""
  description = "Optional: CloudWatch Logs delivery-source ARN for S3 delivery. Empty disables logs delivery policy."
}

variable "logs_account_id" {
  type        = string
  default     = ""
  description = "Optional: AWS account id that delivers logs. Empty disables logs policy (recommended for portable deploy)."
}

variable "logs_prefix" {
  type        = string
  default     = "logs/"
  description = "Optional: prefix for logs objects. Only used if logs_delivery_source_arn/logs_account_id are set."
}

# SES receipt rule -> S3 put permissions (optional)
variable "ses_receipt_rule_arn" {
  type        = string
  default     = ""
  description = "Optional: SES receipt rule ARN. Empty disables SES bucket policy."
}

variable "ses_account_id" {
  type        = string
  default     = ""
  description = "Optional: SES sending account id. Empty disables SES policy."
}

variable "ses_prefix" {
  type        = string
  default     = "emails/"
  description = "Optional: prefix for SES stored emails. Only used if SES vars are set."
}

# Tenant role access (optional)
variable "tenant_role_arn" {
  type        = string
  default     = ""
  description = "Optional: IAM role ARN that should have tenant access to the bucket. Empty disables tenant policy."
}

variable "tenant_tag_pattern" {
  type        = string
  default     = ""
  description = "Optional: aws:PrincipalTag/TenantID pattern for conditional access. Empty disables tag-condition policy."
}


# Tags

variable "tags" {
  type = map(string)
  default = {
    Project  = "University"
    Env      = "Dev"
    Type     = "S3"
    TenantID = ""
  }
}
