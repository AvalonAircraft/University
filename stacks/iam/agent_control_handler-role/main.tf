# Provider

provider "aws" {
  region = var.region
}


# Optional: resolve KMS key ARN from alias (portable)

data "aws_kms_key" "by_alias" {
  count  = (var.kms_key_arn == "" && var.kms_key_alias != "") ? 1 : 0
  key_id = var.kms_key_alias
}

locals {
  effective_kms_key_arn = coalesce(
    nullif(var.kms_key_arn, ""),
    try(data.aws_kms_key.by_alias[0].arn, null),
    ""
  )
}


# Modul: Agent Control Handler

module "role_agent_control_handler" {
  source = "../../../modules/iam/agent_control_handler"

  role_name           = var.role_name
  role_path           = "/service-role/"
  tags                = var.tags

  s3_bucket_name      = var.s3_bucket_name
  kms_key_arn         = local.effective_kms_key_arn
  managed_policy_name = var.managed_policy_name
}


# Outputs

output "role_name" {
  value = module.role_agent_control_handler.role_name
}

output "role_arn" {
  value = module.role_agent_control_handler.role_arn
}
