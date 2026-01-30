#########################################
# stacks/stepfunctions/AgentStepFunction/variables.tf
#########################################

variable "region" {
  type        = string
  description = "AWS region for this stack"
  default     = "us-east-1"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID        = ""
  }
}

############################
# State Machine
############################
variable "state_machine_name" {
  type        = string
  description = "Name of the Step Functions state machine"
  default     = "AgentStepFunction"
}

############################
# IAM Role (optional)
# - Provide either ARN or Name
# - Leave empty if your module creates the role itself
############################
variable "existing_role_arn" {
  type        = string
  description = "Optional: existing IAM role ARN for Step Functions. Leave empty to skip."
  default     = ""
}

variable "existing_role_name" {
  type        = string
  description = "Optional: existing IAM role NAME to look up. Leave empty to skip."
  default     = ""
}

############################
# Lambda target
# - Provide either ARN or Name
############################
variable "lambda6_fn_arn" {
  type        = string
  description = "Lambda function ARN used by the state machine. Can be empty if lambda_function_name is set."
  default     = ""
}

variable "lambda_function_name" {
  type        = string
  description = "Optional: Lambda function NAME to look up and convert to ARN."
  default     = ""
}

############################
# Optional Argument / Input
############################
variable "argument_function_name" {
  type        = string
  description = "Optional argument passed into the Step Function module"
  default     = "MyData"
}

############################
# Logging
############################
variable "enable_logging" {
  type        = bool
  description = "Enable Step Functions logging"
  default     = true
}

variable "log_level" {
  type        = string
  description = "Logging level: ALL | ERROR | FATAL | OFF"
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ERROR", "FATAL", "OFF"], var.log_level)
    error_message = "log_level must be one of: ALL, ERROR, FATAL, OFF."
  }
}

variable "include_execution_data" {
  type        = bool
  description = "Whether to include execution data in logs"
  default     = true
}

# If logging is enabled, provide either ARN or Name.
# Leave empty if your module creates the log group itself.
variable "existing_log_group_arn" {
  type        = string
  description = "Optional: existing CloudWatch Log Group ARN. Leave empty to resolve by name or let module create."
  default     = ""
}

variable "existing_log_group_name" {
  type        = string
  description = "Optional: existing CloudWatch Log Group NAME to look up (e.g. /aws/vendedlogs/states/AgentStepFunction)."
  default     = ""
}
