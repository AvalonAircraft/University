data "aws_partition"       "current" {}
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Umschalter: true = kundenverwaltete Kopien; false = AWS-Managed Standardpolicies
  use_customer_managed = var.use_customer_managed

  # Customer managed (nur wenn im jeweiligen Account vorhanden!)
  policy_arns_customer = [
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/${var.customer_basic_logs_policy_name}",
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/${var.customer_vpc_access_policy_name}",
  ]

  # AWS-managed (immer vorhanden)
  policy_arns_aws_managed = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = local.use_customer_managed ? local.policy_arns_customer : local.policy_arns_aws_managed
}

module "iam_role_Lambda2" {
  source = "../../../modules/iam/lambda2-role"

  role_name   = var.role_name
  role_path   = var.role_path
  policy_arns = local.effective_policy_arns

  bedrock_model_arn = var.bedrock_model_arn
  allow_streaming   = var.allow_streaming

  tags = var.tags
}

output "role_name" { value = module.iam_role_Lambda2.role_name }
output "role_arn"  { value = module.iam_role_Lambda2.role_arn }
