# Provider

provider "aws" {
  region = var.region
}

data "aws_partition"       "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # true  -> customer-managed Kopien (nur wenn im Account vorhanden)
  # false -> AWS-managed Standard (immer vorhanden, portable)
  use_customer_managed = var.use_customer_managed

  # Customer-managed Policies (account-spezifisch)
  policy_arns_customer = [
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/${var.customer_basic_logs_policy_name}",
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/${var.customer_vpc_access_policy_name}",
  ]

  # AWS-managed Policies (account-agnostisch)
  policy_arns_aws_managed = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = local.use_customer_managed ? local.policy_arns_customer : local.policy_arns_aws_managed
}

module "iam_role_lambda5" {
  source = "../../../modules/iam/lambda5-role"

  role_name   = var.role_name
  role_path   = var.role_path
  policy_arns = local.effective_policy_arns
  tags        = var.tags
}

output "role_name" { value = module.iam_role_lambda5.role_name }
output "role_arn"  { value = module.iam_role_lambda5.role_arn }
