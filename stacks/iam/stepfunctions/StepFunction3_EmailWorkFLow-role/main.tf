module "stepfn_email_workflow_role" {
  # auf dein generisches Modul zeigen (ohne GUID im Ordnernamen)
  source = "../../../modules/iam/stepfunctions3_emailworkflow_role"

  role_name        = var.role_name
  role_path        = "/service-role/"
  lambda_resources = var.lambda_resources
  tags             = var.tags

  # optional – wenn ich zentrale Policies schon habe, kann ich lokale Erstellung abschalten
  create_managed_policies      = var.create_managed_policies
  existing_managed_policy_arns = var.existing_managed_policy_arns
}

output "role_name" { value = module.stepfn_email_workflow_role.role_name }
output "role_arn"  { value = module.stepfn_email_workflow_role.role_arn  }
