variable "region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "University"
    Environment = "Dev"
    TenantID    = ""
  }
}

# Logging-Optionen
variable "create_error_log_group" {
  type    = bool
  default = true
}

variable "enable_s3_error_logging" {
  type        = bool
  description = "If true, s3_bucket_name must be set to an existing bucket in the target account."
  default     = false
}

variable "include_execution_data" {
  type    = bool
  default = false
}

# S3 Bucket für ERROR-Logs (optional)
variable "s3_bucket_name" {
  type        = string
  description = "Existing S3 bucket name for EventBridge error logs (required only if enable_s3_error_logging=true)."
  default     = ""

  validation {
    condition     = (var.enable_s3_error_logging == false) || (length(trim(var.s3_bucket_name)) > 0)
    error_message = "enable_s3_error_logging=true requires s3_bucket_name to be a non-empty existing bucket name."
  }
}

# Optional: falls dein Modul Prefix/Folder unterstützt (sonst weglassen)
variable "s3_prefix" {
  type        = string
  description = "S3 prefix for log delivery"
  default     = "AWSLogs"
}

variable "s3_error_folder" {
  type        = string
  description = "Folder under prefix for EventBridge logs"
  default     = "EventBusLogs"
}
