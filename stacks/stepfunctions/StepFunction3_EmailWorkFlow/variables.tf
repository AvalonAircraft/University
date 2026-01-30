variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_machine_name" {
  description = "Name der Step Functions State Machine"
  type        = string
  default     = "StepFunction3_EmailWorkFLow"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "University"
    Environment = "Dev"
    TenantID    = ""
  }
}


# Existing IAM role: ARN OR name

variable "existing_role_arn" {
  description = "Optional: existing StepFunctions IAM role ARN. Leave empty to let module create."
  type        = string
  default     = ""
}

variable "existing_role_name" {
  description = "Optional: existing StepFunctions IAM role NAME (will be resolved to ARN)."
  type        = string
  default     = ""
}


# Lambdas: ARN OR name (name recommended)

variable "lambda_resolve_tenant_arn" { type = string, default = "" }
variable "lambda_move_email_arn"     { type = string, default = "" }
variable "lambda_forward_vpc_arn"    { type = string, default = "" }

variable "lambda_resolve_tenant_name" {
  description = "Lambda function name (preferred) for resolve tenant"
  type        = string
  default     = ""
}

variable "lambda_move_email_name" {
  description = "Lambda function name (preferred) for move email"
  type        = string
  default     = ""
}

variable "lambda_forward_vpc_name" {
  description = "Lambda function name (preferred) for forward vpc"
  type        = string
  default     = ""
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

# Existing LogGroup: ARN OR name
variable "existing_log_group_arn" {
  description = "Optional: existing CloudWatch log group ARN."
  type        = string
  default     = ""
}

variable "existing_log_group_name" {
  description = "Optional: existing CloudWatch log group NAME (will be resolved to ARN)."
  type        = string
  default     = ""
}

# Create LogGroup
variable "create_log_group" {
  description = "If true, module creates a log group (must NOT be used with existing_log_group_*)."
  type        = bool
  default     = true
}

variable "log_group_name" {
  type    = string
  default = "/aws/vendedlogs/states/StepFunction3_EmailWorkFLow-Logs"
}

variable "log_retention_days" {
  type    = number
  default = 30
}


# Guardrails

variable "input_guardrails" {
  description = "Internal guard; do not set."
  type        = string
  default     = "guard"

  validation {
    condition = !(
      trim(var.existing_role_arn) != "" && trim(var.existing_role_name) != ""
    )
    error_message = "Set either existing_role_arn OR existing_role_name, not both."
  }

  validation {
    condition = !(
      var.create_log_group == true &&
      (trim(var.existing_log_group_arn) != "" || trim(var.existing_log_group_name) != "")
    )
    error_message = "create_log_group=true conflicts with existing_log_group_arn/name. Choose one."
  }

  validation {
    condition = alltrue([
      (trim(var.lambda_resolve_tenant_arn) != "" || trim(var.lambda_resolve_tenant_name) != ""),
      (trim(var.lambda_move_email_arn)     != "" || trim(var.lambda_move_email_name) != ""),
      (trim(var.lambda_forward_vpc_arn)    != "" || trim(var.lambda_forward_vpc_name) != "")
    ])
    error_message = "Each lambda needs either *_arn or *_name set."
  }
}
