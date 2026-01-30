# Data (optional; useful for validations)

data "aws_partition" "current" {}
data "aws_region" "current" {}


# Core

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_machine_name" {
  description = "Name der Step Functions State Machine"
  type        = string
  default     = "AgentStepFunction2"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "University"
    Environment = "Dev"
    TenantID    = ""
  }
}


# IAM Role (optional)
# Use ARN OR Role Name (portable)

variable "existing_role_arn" {
  description = "Optional: existing IAM role ARN for Step Functions. Prefer leaving empty and letting module create one, or supply existing_role_name."
  type        = string
  default     = ""
}

variable "existing_role_name" {
  description = "Optional: existing IAM role NAME for Step Functions (will be looked up to ARN in main.tf)."
  type        = string
  default     = ""
}


# Lambda targets (portable)
# Provide either ARN or function name. Name lookup is recommended.

variable "lambda1_fn_arn" { type = string, default = "" }
variable "lambda2_fn_arn" { type = string, default = "" }
variable "lambda3_fn_arn" { type = string, default = "" }
variable "lambda4_fn_arn" { type = string, default = "" }
variable "lambda5_fn_arn" { type = string, default = "" }
variable "lambda6_fn_arn" { type = string, default = "" }

variable "lambda1_fn_name" {
  description = "Lambda function name for step 1 (preferred)."
  type        = string
  default     = "Lambda1"
}
variable "lambda2_fn_name" { type = string, default = "Lambda2" }
variable "lambda3_fn_name" { type = string, default = "Lambda3" }
variable "lambda4_fn_name" { type = string, default = "Lambda4" }
variable "lambda5_fn_name" { type = string, default = "Lambda5" }
variable "lambda6_fn_name" {
  type    = string
  default = "Lambda6_URL-Gen_DB_Saving_SQL-Query"
}


# Logging

variable "enable_logging" {
  type    = bool
  default = true
}

variable "log_level" {
  description = "ALL|ERROR|FATAL|OFF"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ERROR", "FATAL", "OFF"], var.log_level)
    error_message = "log_level must be one of: ALL, ERROR, FATAL, OFF."
  }
}

variable "include_execution_data" {
  type    = bool
  default = true
}

# Existing LogGroup (portable: prefer name)
variable "existing_log_group_arn" {
  description = "Optional: existing CloudWatch log group ARN. Prefer using existing_log_group_name."
  type        = string
  default     = ""
}

variable "existing_log_group_name" {
  description = "Optional: existing CloudWatch log group NAME (looked up to ARN in main.tf)."
  type        = string
  default     = ""
}

# Create LogGroup
variable "create_log_group" {
  description = "If true, module creates a log group. Must not be true when existing_log_group_* is set."
  type        = bool
  default     = true
}

variable "log_group_name" {
  type    = string
  default = "/aws/vendedlogs/states/AgentStepFunction2-Logs"
}

variable "log_retention_days" {
  type    = number
  default = 30
}


# Guardrails (the deploy-stability part)


# Ensure role inputs aren't contradictory
variable "role_input_guard" {
  description = "Internal guard variable; do not set."
  type        = string
  default     = "guard"

  validation {
    condition = !(
      (trim(var.existing_role_arn) != "" && trim(var.existing_role_name) != "")
    )
    error_message = "Set either existing_role_arn OR existing_role_name, not both."
  }
}

# Ensure log group inputs aren't contradictory
variable "log_input_guard" {
  description = "Internal guard variable; do not set."
  type        = string
  default     = "guard"

  validation {
    condition = !(
      var.create_log_group == true &&
      (trim(var.existing_log_group_arn) != "" || trim(var.existing_log_group_name) != "")
    )
    error_message = "create_log_group=true conflicts with existing_log_group_arn/name. Use one approach."
  }
}

# Ensure each lambda has at least name or ARN (name defaults are set, so normally OK)
variable "lambda_input_guard" {
  description = "Internal guard variable; do not set."
  type        = string
  default     = "guard"

  validation {
    condition = alltrue([
      (trim(var.lambda1_fn_arn) != "" || trim(var.lambda1_fn_name) != ""),
      (trim(var.lambda2_fn_arn) != "" || trim(var.lambda2_fn_name) != ""),
      (trim(var.lambda3_fn_arn) != "" || trim(var.lambda3_fn_name) != ""),
      (trim(var.lambda4_fn_arn) != "" || trim(var.lambda4_fn_name) != ""),
      (trim(var.lambda5_fn_arn) != "" || trim(var.lambda5_fn_name) != ""),
      (trim(var.lambda6_fn_arn) != "" || trim(var.lambda6_fn_name) != "")
    ])
    error_message = "Each lambda must have either *_fn_arn or *_fn_name set."
  }
}
