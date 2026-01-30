
# Optional: Resolve Lambda ARN by name (portable)
# - Only runs if target_lambda_arn is empty AND lambda_function_name is provided

data "aws_lambda_function" "target" {
  count         = (trim(var.target_lambda_arn) == "" && trim(var.lambda_function_name) != "") ? 1 : 0
  function_name = var.lambda_function_name
}

locals {
  resolved_target_lambda_arn = coalesce(
    nullif(trim(var.target_lambda_arn), ""),
    try(data.aws_lambda_function.target[0].arn, null)
  )
}


# Safety: fail early if neither ARN nor name resolution works

resource "null_resource" "validate_target_lambda" {
  triggers = {
    resolved_target_lambda_arn = tostring(local.resolved_target_lambda_arn)
  }

  lifecycle {
    precondition {
      condition     = local.resolved_target_lambda_arn != null && local.resolved_target_lambda_arn != ""
      error_message = "No Lambda target available. Set target_lambda_arn OR set lambda_function_name (and ensure the function exists)."
    }
  }
}


# Module call

module "event_bus_emails" {
  source = "../../../modules/eventbridge/event-bus-emails"

  bus_name          = var.bus_name
  rule_name         = var.rule_name
  bucket_name       = var.bucket_name
  key_prefix        = var.key_prefix

  target_lambda_arn = local.resolved_target_lambda_arn
  dlq_arn           = var.dlq_arn
  tags              = var.tags

  depends_on = [null_resource.validate_target_lambda]
}


# Outputs

output "event_bus_arn"  { value = module.event_bus_emails.event_bus_arn }
output "event_rule_arn" { value = module.event_bus_emails.event_rule_arn }
