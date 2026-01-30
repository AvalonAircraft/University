# Provider

provider "aws" {
  region = var.region
}

data "aws_partition"       "current" {}
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  
  # IAM managed policies: customer vs aws-managed
  
  policy_arns_customer = [
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/${var.customer_basic_logs_policy_name}",
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/${var.customer_vpc_access_policy_name}",
  ]

  policy_arns_aws_managed = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = var.use_customer_managed ? local.policy_arns_customer : local.policy_arns_aws_managed
}


# Optional: resolve KMS key ARN by alias (portable)

data "aws_kms_key" "by_alias" {
  count  = (var.kms_key_arn == "" && var.kms_key_alias != "") ? 1 : 0
  key_id = var.kms_key_alias
}

locals {
  effective_kms_key_arn = coalesce(
    nullif(var.kms_key_arn, ""),
    try(data.aws_kms_key.by_alias[0].arn, null)
  )
}


# Module call

module "iam_role_lambda6" {
  source = "../../../modules/iam/lambda6_URL-Gen_DB_Saving_SQL-Query-role"

  role_name   = var.role_name
  role_path   = var.role_path
  policy_arns = local.effective_policy_arns

  # S3 + KMS
  s3_bucket   = var.s3_bucket
  kms_key_arn = local.effective_kms_key_arn

  # Option A: fertige rds-db:connect ARNs (wenn du sie direkt übergeben willst)
  rds_db_users = var.rds_db_users

  # Option B: DBI Resource ID + Usernames (Modul baut daraus ARNs)
  # WICHTIG: Das ist i. d. R. ein dbi-ResourceId (bei Aurora die Instance Resource ID), NICHT "cluster-..."
  rds_cluster_resource_id = var.rds_dbi_resource_id
  rds_db_usernames        = var.rds_db_usernames

  tags = var.tags
}


# Outputs

output "role_name" { value = module.iam_role_lambda6.role_name }
output "role_arn"  { value = module.iam_role_lambda6.role_arn }
