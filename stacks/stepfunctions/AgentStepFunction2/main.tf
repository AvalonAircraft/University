provider "aws" {
  region = var.region
}

module "agent_sfn2" {
  source = "../../../modules/stepfunctions/AgentStepFunction2"

  state_machine_name = "AgentStepFunction2"
  tags               = var.tags

  # IAM-Rolle (bestehend) – wenn leer, erstellt Modul eine Role+Policy
  existing_role_arn = var.existing_role_arn

  # Lambdas
  lambda1_fn = var.lambda1_fn
  lambda2_fn = var.lambda2_fn
  lambda3_fn = var.lambda3_fn
  lambda4_fn = var.lambda4_fn
  lambda5_fn = var.lambda5_fn
  lambda6_fn = var.lambda6_fn

  # Logging
  enable_logging         = var.enable_logging
  log_level              = var.log_level
  include_execution_data = var.include_execution_data

  # Entweder vorhandene LogGroup...
  existing_log_group_arn = var.existing_log_group_arn
  # ...oder neue erstellen lassen:
  create_log_group   = var.create_log_group
  log_group_name     = var.log_group_name
  log_retention_days = var.log_retention_days
}

output "state_machine_arn"  { value = module.agent_sfn2.state_machine_arn }
output "role_arn"           { value = module.agent_sfn2.role_arn }
output "log_group_arn_used" { value = module.agent_sfn2.log_group_arn_used }
