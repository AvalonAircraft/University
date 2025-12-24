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

# Bestehende IAM-Rolle (der eigene Wert)
variable "existing_role_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/service-role/StepFunctions-AgentStepFunction-role-mz4yhuvj7"
}

# Lambda6 ARN (die eigene Funktion)
variable "lambda6_fn_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda6_URL-Gen_DB_Saving_SQL-Query"
}

# Optionales Argument
variable "argument_function_name" { type = string, default = "MyData" }

# Logging – nutzt bestehende Log Group
variable "enable_logging"         { type = bool,   default = true }
variable "log_level"              { type = string, default = "ALL" }     # ALL|ERROR|FATAL|OFF
variable "include_execution_data" { type = bool,   default = true }

# Bestehende Log Group ARN (der eigene Wert)
variable "existing_log_group_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/states/MyStateMachine-Logs:*"
}
