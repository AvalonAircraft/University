provider "aws" {
  region = var.region
}

module "ecs_task_execution_role" {
  source = "../../../modules/iam/ecs_task_execution_role"

  role_name         = var.role_name
  role_path         = "/"
  tags              = var.tags
  extra_policy_arns = var.extra_policy_arns
}

output "role_name" { value = module.ecs_task_execution_role.role_name }
output "role_arn"  { value = module.ecs_task_execution_role.role_arn }
