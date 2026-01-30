# Bus & Rule

variable "bus_name" {
  type    = string
  default = "event-bus-emails"
}

variable "rule_name" {
  type    = string
  default = "Email_S3-To_Lambda"
}


# S3 Filter

variable "bucket_name" {
  type        = string
  description = "S3 bucket name that emits the events (must exist in the same account/region)."
}

variable "key_prefix" {
  type        = string
  description = "S3 key prefix filter (recommended to end with '/'), e.g. 'emails/'."
  default     = "emails/"
}


# Target Lambda
# - Either provide target_lambda_arn OR lambda_function_name

variable "target_lambda_arn" {
  type        = string
  description = "Optional: direct Lambda ARN. If set, lookup by name is skipped."
  default     = ""
}

variable "lambda_function_name" {
  type        = string
  description = "Optional: Lambda function name to look up. Used only if target_lambda_arn is empty."
  default     = ""
}


# Optional: DLQ

variable "dlq_arn" {
  type        = string
  description = "Optional DLQ ARN for EventBridge target (SQS). Leave empty to disable."
  default     = ""
}


# Tags

variable "tags" {
  type = map(string)
  default = {
    Project     = "University"
    Environment = "Dev"
    Type        = "EventBridge"
    TenantID    = ""
  }
}
