module "stepfunctions_agent_role" {
  # neuer generischer Modulpfad ohne GUID im Verzeichnisnamen
  source         = "../../../modules/iam/stepfunctions_role_agent"

  role_name      = var.role_name
  role_path      = "/service-role/"
  lambda_arns    = var.lambda_arns
  log_group_arns = var.log_group_arns
  tags           = var.tags

  # Schalter: Policies lokal erzeugen oder vorhandene anhängen
  create_managed_policies      = var.create_managed_policies
  existing_managed_policy_arns = var.existing_managed_policy_arns
}

output "role_name" { value = module.stepfunctions_agent_role.role_name }
output "role_arn"  { value = module.stepfunctions_agent_role.role_arn  }
