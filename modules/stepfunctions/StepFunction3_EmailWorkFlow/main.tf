############################
# Data (agnostisch)
############################
data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

############################
# Inputs
############################
variable "state_machine_name" { type = string, default = "StepFunction3_EmailWorkFLow" }
variable "tags"               { type = map(string), default = {} }

# Wenn gesetzt, wird keine neue Rolle/POLICY erstellt.
variable "existing_role_arn"  { type = string, default = "" }

# Lambda ARNs (aus deiner Umgebung)
variable "lambda_resolve_tenant_arn" { type = string } # z.B. Lambda6_URL-Gen_DB_Saving_SQL-Query
variable "lambda_move_email_arn"     { type = string } # z.B. Lambda
variable "lambda_forward_vpc_arn"    { type = string } # z.B. AgentControlHandler

# Logging (Option A: bestehende LogGroup nutzen; Option B: vom Modul erstellen lassen)
variable "enable_logging"         { type = bool,   default = false }
variable "existing_log_group_arn" { type = string, default = "" }  # volle ARN der LogGroup
variable "create_log_group"       { type = bool,   default = false }
variable "log_group_name"         { type = string, default = "/aws/states/StepFunction3_EmailWorkFLow" }
variable "log_retention_days"     { type = number, default = 30 }
variable "log_level"              { type = string, default = "ERROR" } # ALL|ERROR|FATAL|OFF
variable "include_execution_data" { type = bool,   default = false }

############################
# Locals
############################
locals {
  tags    = var.tags
  use_ext = length(var.existing_role_arn) > 0

  # Logging-Ziel-ARN bestimmen
  log_destination_arn = var.enable_logging ? (
    length(var.existing_log_group_arn) > 0
      ? var.existing_log_group_arn
      : (var.create_log_group ? aws_cloudwatch_log_group.sfn[0].arn : null)
  ) : null
}

############################
# IAM Role (nur wenn keine externe übergeben)
############################
data "aws_iam_policy_document" "sfn_assume" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["states.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "sfn_role" {
  count              = local.use_ext ? 0 : 1
  name               = "service-role/${var.state_machine_name}-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
  tags               = local.tags
}

# Minimalrechte: Lambda-Invoke (nur wenn Rolle vom Modul)
data "aws_iam_policy_document" "sfn_invoke_lambdas" {
  statement {
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = [
      var.lambda_resolve_tenant_arn,
      var.lambda_move_email_arn,
      var.lambda_forward_vpc_arn
    ]
  }
}

resource "aws_iam_role_policy" "sfn_invoke_lambdas" {
  count  = local.use_ext ? 0 : 1
  name   = "InvokeLambdas-${var.state_machine_name}"
  role   = aws_iam_role.sfn_role[0].id
  policy = data.aws_iam_policy_document.sfn_invoke_lambdas.json
}

############################
# Optional: CloudWatch Log Group
############################
resource "aws_cloudwatch_log_group" "sfn" {
  count             = var.enable_logging && length(var.existing_log_group_arn) == 0 && var.create_log_group ? 1 : 0
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
  tags              = merge(local.tags, { Name = var.log_group_name })
}

############################
# ASL Definition (STANDARD)
############################
locals {
  role_arn = local.use_ext ? var.existing_role_arn : aws_iam_role.sfn_role[0].arn

  definition = jsonencode({
    Comment = "Resolve tenant via Lambda6, move email, then forward into VPC/NLB/ECS"
    StartAt = "ResolveTenant"
    States  = {
      ResolveTenant = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_resolve_tenant_arn
          Payload = {
            "email.$" = "$.email"
          }
        }
        TimeoutSeconds = 20
        Retry = [{
          ErrorEquals     = ["Lambda.TooManyRequestsException","Lambda.ServiceException","States.Timeout"]
          IntervalSeconds = 1
          BackoffRate     = 2
          MaxAttempts     = 4
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "FailPermanent"
        }]
        ResultSelector = { "resolver.$" = "$.Payload" }
        ResultPath     = "$.r"
        Next           = "CheckTenant"
      }

      CheckTenant = {
        Type    = "Choice"
        Choices = [{
          Variable     = "$.r.resolver.tenant_id"
          StringEquals = "unknown"
          Next         = "QuarantineUnknown"
        }]
        Default = "MoveEmail"
      }

      QuarantineUnknown = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_move_email_arn
          Payload = {
            mode       = "move"
            "bucket.$" = "$.bucket"
            "key.$"    = "$.key"
            tenant_id  = "_unknown"
            routing = { s3_prefix = "tenants/_unknown/emails/" }
          }
        }
        End = true
      }

      MoveEmail = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_move_email_arn
          Payload = {
            mode          = "move"
            "bucket.$"    = "$.bucket"
            "key.$"       = "$.key"
            "tenant_id.$" = "$.r.resolver.tenant_id"
            "routing.$"   = "$.r.resolver.routing"
          }
        }
        ResultSelector = { "move_result.$" = "$.Payload" }
        ResultPath     = "$.move_result"
        TimeoutSeconds = 30
        Retry = [{
          ErrorEquals     = ["Lambda.TooManyRequestsException","Lambda.ServiceException","States.Timeout"]
          IntervalSeconds = 1
          BackoffRate     = 2
          MaxAttempts     = 4
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "FailPermanent"
        }]
        Next = "ForwardToVpc"
      }

      ForwardToVpc = {
        Type      = "Task"
        Comment   = "VPC-Lambda ruft NLB → ECS/Fargate (tenant-spezifisch)"
        Resource  = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        OutputPath= "$.Payload"
        Parameters = {
          FunctionName = var.lambda_forward_vpc_arn
          Payload = {
            "tenantId.$"    = "$.r.resolver.tenant_id"
            "bucket.$"      = "$.bucket"
            "key.$"         = "$.key"
            "routing.$"     = "$.r.resolver.routing"
            "move_result.$" = "$.move_result"
          }
        }
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException","Lambda.AWSLambdaException","Lambda.SdkClientException","States.TaskFailed","States.Timeout"]
          IntervalSeconds = 5
          BackoffRate     = 2
          MaxAttempts     = 6
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.fwd_error"
          Next        = "FailPermanent"
        }]
        Next = "Success"
      }

      Success = { Type = "Succeed" }

      FailPermanent = {
        Type  = "Fail"
        Error = "PermanentFailure"
        Cause = "Unrecoverable error"
      }
    }
  })
}

############################
# State Machine (STANDARD)
############################
resource "aws_sfn_state_machine" "this" {
  name       = var.state_machine_name
  role_arn   = local.role_arn
  type       = "STANDARD"
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
output "state_machine_arn" { value = aws_sfn_state_machine.this.arn }
output "role_arn"          { value = local.role_arn }
