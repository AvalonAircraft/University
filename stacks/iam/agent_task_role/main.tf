provider "aws" {
  region = var.region
}

module "agent_task_role" {
  source = "../../../modules/iam/agent_task_role"

  role_name        = var.role_name
  role_path        = "/"
  tags             = var.tags

  s3_bucket_name   = var.s3_bucket_name
  kms_key_arn      = var.kms_key_arn

  bedrock_model_id = var.bedrock_model_id

  event_bus_name   = var.event_bus_name
  event_bus_arn    = var.event_bus_arn
}

output "role_name" { value = module.agent_task_role.role_name }
output "role_arn"  { value = module.agent_task_role.role_arn }
