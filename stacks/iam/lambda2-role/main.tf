data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Umschalter: true = kundenverwaltete Kopien; false = AWS-Managed Standardpolicies
  use_customer_managed = var.use_customer_managed

  policy_arns_customer = [
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaBasicExecutionRole-2d852cb3-ed3b-43fa-8a18-293eb1794f3d",
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaVPCAccessExecutionRole-34d15055-e437-426b-9420-0db4540b4a84",
  ]

  policy_arns_aws_managed = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = local.use_customer_managed ? local.policy_arns_customer : local.policy_arns_aws_managed
}

module "iam_role_Lambda2" {
  source = "../../../modules/iam/lambda2-role"

  role_name         = var.role_name
  role_path         = "/service-role/"
  policy_arns       = local.effective_policy_arns

  bedrock_model_arn = var.bedrock_model_arn
  allow_streaming   = var.allow_streaming

  tags = var.tags
}

output "role_name" { value = module.iam_role_Lambda2.role_name }
output "role_arn"  { value = module.iam_role_Lambda2.role_arn  }
