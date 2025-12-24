############################
# Provider
############################
provider "aws" {
  region = var.region
}

############################
# Modul: Agent Control Handler
############################
module "role_agent_control_handler" {
  source = "../../../modules/iam/agent_control_handler"

  role_name           = var.role_name
  role_path           = "/service-role/"
  tags                = var.tags

  s3_bucket_name      = var.s3_bucket_name
  kms_key_arn         = var.kms_key_arn
  managed_policy_name = var.managed_policy_name
}

############################
# Outputs
############################
output "role_name" {
  value = module.role_agent_control_handler.role_name
}

output "role_arn" {
  value = module.role_agent_control_handler.role_arn
}
