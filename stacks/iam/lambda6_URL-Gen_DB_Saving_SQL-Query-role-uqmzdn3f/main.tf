data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Umschalter: nutze kundenverwaltete Policies (IDs sind je Account unterschiedlich) ODER AWS-managed.
  use_customer_managed = true

  policy_arns_customer = [
    # Falls im Ziel-Account vorhanden (deine Kunden-Policies aus der Konsole):
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaBasicExecutionRole-add46fc8-c3a5-4517-9fe1-3f09334e9cbb",
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaVPCAccessExecutionRole-0fe47f9d-64d9-43d6-a708-f959cb55630f",
  ]

  policy_arns_aws_managed = [
    # Fallback (immer verfügbar, account-agnostisch):
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = local.use_customer_managed ? local.policy_arns_customer : local.policy_arns_aws_managed
}

module "iam_role_lambda6" {
  source = "../../../modules/iam/lambda6_URL-Gen_DB_Saving_SQL-Query-role"

  role_name   = var.role_name
  role_path   = "/service-role/"
  policy_arns = local.effective_policy_arns

  # S3 + KMS
  s3_bucket   = var.s3_bucket
  kms_key_arn = var.kms_key_arn

  # EITHER: fertige rds-db:connect ARNs (leer lassen, wenn Option B genutzt wird)
  rds_db_users = var.rds_db_users

  # OR: Cluster-Resource-ID + Usernames (werden zu ARNs zusammengesetzt)
  rds_cluster_resource_id = var.rds_cluster_resource_id
  rds_db_usernames        = var.rds_db_usernames

  tags = var.tags
}

output "role_name" { value = module.iam_role_lambda6.role_name }
output "role_arn"  { value = module.iam_role_lambda6.role_arn  }
