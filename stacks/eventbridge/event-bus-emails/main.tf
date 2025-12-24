############################
# Resolve Lambda ARN by name (portable)
############################
data "aws_lambda_function" "target" {
  function_name = var.lambda_function_name
}

############################
# Module call
############################
module "event_bus_emails" {
  source = "../../../modules/eventbridge/event-bus-emails"

  bus_name          = var.bus_name
  rule_name         = var.rule_name
  bucket_name       = var.bucket_name
  key_prefix        = var.key_prefix
  target_lambda_arn = data.aws_lambda_function.target.arn
  dlq_arn           = var.dlq_arn
  tags              = var.tags
}

############################
# Outputs
############################
output "event_bus_arn"  { value = module.event_bus_emails.event_bus_arn }
output "event_rule_arn" { value = module.event_bus_emails.event_rule_arn }
