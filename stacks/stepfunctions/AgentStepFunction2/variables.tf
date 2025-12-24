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

# bestehende IAM-Rolle (der eigene Wert) – wenn leer, erstellt das Modul eine Rolle
variable "existing_role_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/service-role/StepFunctions-AgentStepFunction2-role-1zpprn9cu"
}

# Lambda FunctionName/ARNs
variable "lambda1_fn" { type = string, default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda1:$LATEST" }
variable "lambda2_fn" { type = string, default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda2:$LATEST" }
variable "lambda3_fn" { type = string, default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda3:$LATEST" }
variable "lambda4_fn" { type = string, default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda4:$LATEST" }
variable "lambda5_fn" { type = string, default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda5:$LATEST" }
variable "lambda6_fn" { type = string, default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda6_URL-Gen_DB_Saving_SQL-Query:$LATEST" }

# Logging – vorhandene Log Group ARN (der eigene Wert) ODER neue erstellen lassen
variable "enable_logging"         { type = bool,   default = true }
variable "log_level"              { type = string, default = "ALL" }
variable "include_execution_data" { type = bool,   default = true }

variable "existing_log_group_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/states/AgentStepFunction2-Logs:*"
}

# nur falls NICHT existing_log_group_arn verwendet:
variable "create_log_group"   { type = bool,   default = false }
variable "log_group_name"     { type = string, default = "/aws/vendedlogs/states/AgentStepFunction2-Logs" }
variable "log_retention_days" { type = number, default = 30 }
