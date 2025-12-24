data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region" { type = string, default = "us-east-1" }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID = ""
  }
}

# Ziel: Step Functions
variable "step_function_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:AgentStepFunction2"
}

# Optionen
variable "enable_schema_discovery" { type = bool, default = true }

# Logging-Optionen
variable "create_error_log_group"  { type = bool, default = true }
variable "enable_s3_error_logging" { type = bool, default = true }
variable "include_execution_data"  { type = bool, default = false }

# S3 Bucket für ERROR-Logs
variable "s3_bucket_name" { type = string, default = "miraedrive-assets" }
