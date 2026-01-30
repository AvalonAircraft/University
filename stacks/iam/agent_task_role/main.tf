# Provider

provider "aws" {
  region = var.region
}


# Account-agnostic helpers

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# Optional: resolve KMS Key ARN by alias (portable)

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

  # Resolve EventBridge bus ARN if not provided
  # NOTE: EventBridge bus ARN format is stable and safe to construct.
  effective_event_bus_arn = coalesce(
    nullif(var.event_bus_arn, ""),
    "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/${var.event_bus_name}"
  )
}

############################
# Module: agent_task_role

module "agent_task_role" {
  source = "../../../modules/iam/agent_task_role"

  role_name = var.role_name
  role_path = var.role_path
  tags      = var.tags

  # REQUIRED per account/stage
  s3_bucket_name = var.s3_bucket_name

  # optional, portable
  kms_key_arn = local.effective_kms_key_arn

  bedrock_model_id = var.bedrock_model_id

  event_bus_name = var.event_bus_name
  event_bus_arn  = local.effective_event_bus_arn
}


# Outputs

output "role_name" { value = module.agent_task_role.role_name }
output "role_arn"  { value = module.agent_task_role.role_arn }
