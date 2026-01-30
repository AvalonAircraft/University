# Module: StepFunction-Orchestrator


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}


# Inputs


variable "state_machine_name" { type = string, default = "AgentStepFunction" }
variable "tags"               { type = map(string), default = {} }

# Bestehende IAM-Rolle (muss sfn.amazonaws.com vertrauen)
variable "existing_role_arn"  { 
  type        = string 
  description = "ARN der Rolle mit Lambda-, Log- und SFN-Berechtigungen."
}

# Lambda-ARN Integration
variable "lambda6_fn_arn" {
  type    = string
  default = "arn:aws:lambda:eu-central-1:123456789012:function:Lambda6_URL-Gen_DB_Saving_SQL-Query"
}

# Task-Argumente
variable "argument_function_name" { type = string, default = "MyData" }

# Logging
variable "enable_logging"         { type = bool,   default = true }
variable "log_level"              { type = string, default = "ALL" } 
variable "include_execution_data" { type = bool,   default = true }
variable "existing_log_group_arn" { type = string }


# State Machine Definition (JSONata)


locals {
  definition = jsonencode({
    Comment       = "MiraeDrive Orchestration: Lambda 6 (URL-Gen & SQL Query)"
    StartAt       = "InvokeLambda6"
    QueryLanguage = "JSONata"
    States = {
      "InvokeLambda6" = {
        Type     = "Task"
        Resource = var.lambda6_fn_arn
        # JSONata Extraktion des Payloads
        Output   = "{% $states.result.Payload %}"
        Arguments = {
          FunctionName = var.argument_function_name
          # Hier können weitere Input-Daten gemappt werden
        }
        Retry = [{
          ErrorEquals     = [
            "Lambda.ServiceException", 
            "Lambda.AWSLambdaException", 
            "Lambda.SdkClientException", 
            "Lambda.TooManyRequestsException"
          ]
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


# State Machine (EXPRESS)


resource "aws_sfn_state_machine" "this" {
  name     = var.state_machine_name
  type     = "EXPRESS"
  role_arn = var.existing_role_arn

  definition = local.definition

  dynamic "logging_configuration" {
    for_each = var.enable_logging ? [1] : []
    content {
      include_execution_data = var.include_execution_data
      level                  = var.log_level
      # WICHTIG: Erwartet ARN der Log-Group (muss :* am Ende haben, falls nicht von Data Source geliefert)
      log_destination        = var.existing_log_group_arn
    }
  }

  tags = merge(var.tags, { 
    Name        = var.state_machine_name
    Component   = "Orchestrator"
    StepFunctionType = "Express"
  })
}


# Outputs


output "state_machine_arn" { value = aws_sfn_state_machine.this.arn }
output "state_machine_name" { value = aws_sfn_state_machine.this.name }
