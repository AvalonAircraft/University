data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region" {
  type    = string
  default = "us-east-1"
}


# Tags (neutral & portable)

variable "tags" {
  type = map(string)
  default = {
    Project     = "University"
    Environment = "Dev"
    TenantID    = ""
  }
}


# StepFunctions target (portable)
# -> entweder ARN ODER Name

variable "step_function_arn" {
  type        = string
  description = "Optional: State machine ARN. If empty, step_function_name will be used to look it up."
  default     = ""
}

variable "step_function_name" {
  type        = string
  description = "Optional: State machine NAME to look up (used if step_function_arn is empty)."
  default     = "AgentStepFunction2"
}


# Options

variable "enable_schema_discovery" {
  type    = bool
  default = false
}


# Logging options (safe defaults)

variable "create_error_log_group" {
  type    = bool
  default = true
}

variable "enable_s3_error_logging" {
  type        = bool
  description = "If true, s3_bucket_name must be set to an existing bucket."
  default     = false
}

variable "include_execution_data" {
  type    = bool
  default = false
}


# S3 Bucket for error logs (optional)

variable "s3_bucket_name" {
  type        = string
  description = "Existing S3 bucket name for EventBridge delivery logs (required only if enable_s3_error_logging=true)."
  default     = ""
}
