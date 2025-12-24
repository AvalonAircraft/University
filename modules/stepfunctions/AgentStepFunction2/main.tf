############################
# Data (agnostisch)
############################
data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

############################
# Inputs
############################
variable "state_machine_name" { type = string, default = "AgentStepFunction2" }
variable "tags"               { type = map(string), default = {} }

# Wenn gesetzt, wird keine neue Rolle/POLICY erstellt.
variable "existing_role_arn"  { type = string, default = "" }

# Lambda FunctionName/ARN (kann auch :$LATEST enthalten)
variable "lambda1_fn" { type = string }
variable "lambda2_fn" { type = string }
variable "lambda3_fn" { type = string }
variable "lambda4_fn" { type = string }
variable "lambda5_fn" { type = string }
variable "lambda6_fn" { type = string }

# Logging
variable "enable_logging"         { type = bool,   default = true }
variable "log_level"              { type = string, default = "ALL" }     # ALL|ERROR|FATAL|OFF
variable "include_execution_data" { type = bool,   default = true }

# (A) vorhandene Log Group ARN (wenn leer und create_log_group=true -> wird erstellt)
variable "existing_log_group_arn" { type = string, default = "" }

# (B) falls nicht vorhanden, kann das Modul eine Log Group erstellen:
variable "create_log_group"   { type = bool,   default = false }
variable "log_group_name"     { type = string, default = "/aws/vendedlogs/states/AgentStepFunction2-Logs" }
variable "log_retention_days" { type = number, default = 30 }

############################
# Locals
############################
locals {
  tags              = var.tags
  use_ext_role      = length(var.existing_role_arn) > 0
  use_ext_log_group = length(var.existing_log_group_arn) > 0
}

############################
# IAM Role 
############################
data "aws_iam_policy_document" "sfn_assume" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["states.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "sfn_role" {
  count              = local.use_ext_role ? 0 : 1
  name               = "service-role/${var.state_machine_name}-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
  tags               = local.tags
}

# Minimal: lambda:InvokeFunction 
data "aws_iam_policy_document" "sfn_invoke_lambdas" {
  statement {
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = [
      var.lambda1_fn,
      var.lambda2_fn,
      var.lambda3_fn,
      var.lambda4_fn,
      var.lambda5_fn,
      var.lambda6_fn
    ]
  }
}

resource "aws_iam_role_policy" "sfn_invoke_lambdas" {
  count  = local.use_ext_role ? 0 : 1
  name   = "InvokeLambdas-${var.state_machine_name}"
  role   = aws_iam_role.sfn_role[0].id
  policy = data.aws_iam_policy_document.sfn_invoke_lambdas.json
}

############################
# CloudWatch Log Group (optional – nur wenn keine vorhandene übergeben)
############################
resource "aws_cloudwatch_log_group" "sfn" {
  count             = var.enable_logging && !local.use_ext_log_group && var.create_log_group ? 1 : 0
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
  tags              = merge(local.tags, { Name = var.log_group_name })
}

############################
# ASL Definition
############################
locals {
  role_arn = local.use_ext_role ? var.existing_role_arn : aws_iam_role.sfn_role[0].arn

  # Logging Ziel
  log_destination_arn = var.enable_logging ? (
    local.use_ext_log_group
      ? var.existing_log_group_arn
      : (var.create_log_group ? aws_cloudwatch_log_group.sfn[0].arn : null)
  ) : null

  definition = jsonencode({
    Comment = "AgentStepFunction2 — Email ingest pipeline"
    StartAt = "Lambda1(Validierung)"
    States = {
      "Lambda1(Validierung)" = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda1_fn
          "Payload.$"  = "$"
        }
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException","Lambda.AWSLambdaException","Lambda.SdkClientException","Lambda.TooManyRequestsException"]
          IntervalSeconds = 1
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        OutputPath = "$.Payload"
        Next       = "Enrichment (Parallel)"
      }

      "Enrichment (Parallel)" = {
        Type     = "Parallel"
        Branches = [
          {
            StartAt = "Lambda2(Vektor-Embedding)"
            States = {
              "Lambda2(Vektor-Embedding)" = {
                Type     = "Task"
                Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
                Parameters = {
                  FunctionName = var.lambda2_fn
                  "Payload.$"  = "$"
                }
                Retry = [{
                  ErrorEquals     = ["Lambda.ServiceException","Lambda.AWSLambdaException","Lambda.SdkClientException","Lambda.TooManyRequestsException"]
                  IntervalSeconds = 1
                  MaxAttempts     = 3
                  BackoffRate     = 2
                }]
                OutputPath = "$.Payload"
                End        = true
              }
            }
          },
          {
            StartAt = "Lambda3(S3-Upload+PDF)"
            States = {
              "Lambda3(S3-Upload+PDF)" = {
                Type     = "Task"
                Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
                Parameters = {
                  FunctionName = var.lambda3_fn
                  "Payload.$"  = "$"
                }
                Retry = [{
                  ErrorEquals     = ["Lambda.ServiceException","Lambda.AWSLambdaException","Lambda.SdkClientException","Lambda.TooManyRequestsException"]
                  IntervalSeconds = 1
                  MaxAttempts     = 3
                  BackoffRate     = 2
                }]
                OutputPath = "$.Payload"
                End        = true
              }
            }
          }
        ]
        ResultSelector = {
          "embedding.$" = "$[0]"
          "document.$"  = "$[1]"
        }
        ResultPath = "$.enrichment"
        Next       = "Lambda4(Live-Update-Dashboard)"
      }

      "Lambda4(Live-Update-Dashboard)" = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda4_fn
          "Payload.$"  = "$"
        }
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException","Lambda.AWSLambdaException","Lambda.SdkClientException","Lambda.TooManyRequestsException"]
          IntervalSeconds = 1
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        OutputPath = "$.Payload"
        Next       = "Lambda5(DateiInfo-Verteilung+Sync-Prep)"
      }

      "Lambda5(DateiInfo-Verteilung+Sync-Prep)" = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda5_fn
          "Payload.$"  = "$"
        }
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException","Lambda.AWSLambdaException","Lambda.SdkClientException","Lambda.TooManyRequestsException"]
          IntervalSeconds = 1
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        OutputPath = "$.Payload"
        Next       = "Lambda6(Aurora-DB-Write)"
      }

      "Lambda6(Aurora-DB-Write)" = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda6_fn
          "Payload.$"  = "$"
        }
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException","Lambda.AWSLambdaException","Lambda.SdkClientException","Lambda.TooManyRequestsException"]
          IntervalSeconds = 1
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        OutputPath = "$.Payload"
        End        = true
      }
    }
  })
}

############################
# State Machine (EXPRESS)
############################
resource "aws_sfn_state_machine" "this" {
  name       = var.state_machine_name
  role_arn   = local.role_arn
  type       = "EXPRESS"
  definition = local.definition
  tags       = merge(local.tags, { Name = var.state_machine_name })

  dynamic "logging_configuration" {
    for_each = var.enable_logging && local.log_destination_arn != null ? [1] : []
    content {
      include_execution_data = var.include_execution_data
      level                  = var.log_level
      log_destination        = local.log_destination_arn
    }
  }
}

############################
# Outputs
############################
output "state_machine_arn"  { value = aws_sfn_state_machine.this.arn }
output "role_arn"           { value = local.role_arn }
output "log_group_arn_used" { value = local.log_destination_arn }
