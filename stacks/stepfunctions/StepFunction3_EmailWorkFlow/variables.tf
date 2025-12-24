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

# Vorhandene IAM-Rolle (leer lassen -> Modul erstellt Rolle)
variable "existing_role_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/service-role/StepFunctions-StepFunction3_EmailWorkFLow-role-orz7d9h6m"
}

# Lambda ARNs (die eigene Umgebung)
variable "lambda_resolve_tenant_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda6_URL-Gen_DB_Saving_SQL-Query"
}
variable "lambda_move_email_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda"
}
variable "lambda_forward_vpc_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:AgentControlHandler"
}

# Logging (Option A: vorhandene LogGroup-ARN)
variable "enable_logging"         { type = bool,   default = false }
variable "existing_log_group_arn" { type = string, default = "" }

# Logging (Option B: LogGroup erstellen)
variable "create_log_group"   { type = bool,   default = false }
variable "log_group_name"     { type = string, default = "/aws/states/StepFunction3_EmailWorkFLow" }
variable "log_retention_days" { type = number, default = 30 }

# Level + Payload
variable "log_level"              { type = string, default = "ERROR" }
variable "include_execution_data" { type = bool,   default = false }
