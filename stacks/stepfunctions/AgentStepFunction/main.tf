provider "aws" {
  region = var.region
}

module "agent_sfn" {
  source = "../../../modules/stepfunctions/AgentStepFunction"

  state_machine_name     = "AgentStepFunction"
  tags                   = var.tags

  existing_role_arn      = var.existing_role_arn
  lambda6_fn_arn         = var.lambda6_fn_arn
  argument_function_name = var.argument_function_name

  enable_logging         = var.enable_logging
  log_level              = var.log_level
  include_execution_data = var.include_execution_data
  existing_log_group_arn = var.existing_log_group_arn
}

output "state_machine_arn"  { value = module.agent_sfn.state_machine_arn }
output "role_arn"           { value = module.agent_sfn.role_arn }
output "log_group_arn_used" { value = module.agent_sfn.log_group_arn_used }
