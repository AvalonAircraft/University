provider "aws" {
  region = var.region
}

module "stepfunction3" {
  source = "../../../modules/stepfunctions/StepFunction3_EmailWorkFLow"

  state_machine_name = "StepFunction3_EmailWorkFLow"
  tags               = var.tags

  # vorhandene Rolle nutzen (leer lassen ⇒ Modul erstellt Rolle+Policy)
  existing_role_arn = var.existing_role_arn

  # Lambda-Ziele
  lambda_resolve_tenant_arn = var.lambda_resolve_tenant_arn
  lambda_move_email_arn     = var.lambda_move_email_arn
  lambda_forward_vpc_arn    = var.lambda_forward_vpc_arn

  # Logging (entweder bestehende LogGroup ODER erstellen)
  enable_logging         = var.enable_logging
  existing_log_group_arn = var.existing_log_group_arn
  create_log_group       = var.create_log_group
  log_group_name         = var.log_group_name
  log_retention_days     = var.log_retention_days
  log_level              = var.log_level
  include_execution_data = var.include_execution_data
}

output "state_machine_arn" { value = module.stepfunction3.state_machine_arn }
output "role_arn"          { value = module.stepfunction3.role_arn }
