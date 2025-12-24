data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Umschalter: true = kundenverwaltete Kopien; false = AWS-Managed Standardpolicies
  use_customer_managed = var.use_customer_managed

  policy_arns_customer = [
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaBasicExecutionRole-702c2e05-7e66-486b-9ef8-4b1c12bb7d66",
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaVPCAccessExecutionRole-876f699d-a632-4f23-be58-2b0bc68ea401",
  ]

  policy_arns_aws_managed = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = local.use_customer_managed ? local.policy_arns_customer : local.policy_arns_aws_managed
}

module "iam_role_Lambda3" {
  source = "../../../modules/iam/lambda3-role"

  role_name   = var.role_name
  role_path   = "/service-role/"
  policy_arns = local.effective_policy_arns

  bucket_name = var.bucket_name
  tags        = var.tags
}

output "role_name" { value = module.iam_role_Lambda3.role_name }
output "role_arn"  { value = module.iam_role_Lambda3.role_arn  }
