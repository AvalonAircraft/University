############################
# Data (agnostisch)
############################
data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

############################
# Inputs
############################
variable "state_machine_name" { type = string, default = "AgentStepFunction" }
variable "tags"               { type = map(string), default = {} }

# Bestehende IAM-Rolle (mit sfn:StartExecution, logs:CreateLogStream/PutLogEvents, lambda:InvokeFunction)
variable "existing_role_arn"  { type = string }

# Direkte Lambda-ARN (wie von dir vorgegeben)
variable "lambda6_fn_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:123456789012:function:Lambda6_URL-Gen_DB_Saving_SQL-Query"
}

# Task-Argumente
variable "argument_function_name" { type = string, default = "MyData" }

# Logging
variable "enable_logging"         { type = bool,   default = true }
variable "log_level"              { type = string, default = "ALL" }     # ALL|ERROR|FATAL|OFF
variable "include_execution_data" { type = bool,   default = true }

# Vorhandene Log Group ARN (vollständige ARN inkl. log-group:... )
variable "existing_log_group_arn" { type = string }

############################
# Definition (States JSON)
############################
locals {
  definition = jsonencode({
    Comment       = "Lambda 6 (URL-Gen & DB-Speicherung + SQL Abfrage)"
    StartAt       = "Lambda 6 (URL-Gen & DB-Speicherung + SQL Abfrage)"
    QueryLanguage = "JSONata"
    States = {
      "Lambda 6 (URL-Gen & DB-Speicherung + SQL Abfrage)" = {
        Type     = "Task"
        # exakt wie gefordert: direkte Lambda-ARN
        Resource = var.lambda6_fn_arn
        # States v2 Felder wie von dir genutzt:
        Output    = "{% $states.result.Payload %}"
        Arguments = {
          FunctionName = var.argument_function_name
        }
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException","Lambda.AWSLambdaException","Lambda.SdkClientException","Lambda.TooManyRequestsException"]
          IntervalSeconds = 1
          MaxAttempts     = 3
          BackoffRate     = 2
          JitterStrategy  = "FULL"
        }]
        End = true
      }
    }
  })
}

############################
# State Machine (EXPRESS)
############################
resource "aws_sfn_state_machine" "this" {
  name       = var.state_machine_name
  type       = "EXPRESS"
  role_arn   = var.existing_role_arn
  definition = local.definition

  # Optionales Logging
  dynamic "logging_configuration" {
    for_each = var.enable_logging ? [1] : []
    content {
      include_execution_data = var.include_execution_data
      level                  = var.log_level
      # Muss eine LogGroup-ARN sein (kein Name)
      log_destination        = var.existing_log_group_arn
    }
  }

  # (Optional) Tracing kann hier später ergänzt werden
  tags = merge(var.tags, { Name = var.state_machine_name })
}

############################
# Outputs
############################
output "state_machine_arn"  { value = aws_sfn_state_machine.this.arn }
output "role_arn"           { value = var.existing_role_arn }
output "log_group_arn_used" { value = var.existing_log_group_arn }
