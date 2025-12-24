data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Umschalter: true = meine kundenverwalteten Policies verwenden (falls vorhanden),
  # false = auf AWS-Managed zurückfallen (immer verfügbar, account-agnostisch)
  use_customer_managed = var.use_customer_managed

  policy_arns_customer = [
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaBasicExecutionRole-0d5c5f13-6de7-4df6-9414-672fb66dd47c",
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaVPCAccessExecutionRole-02e28b66-c82c-4a09-b5a5-1e3bceb961b8",
  ]

  policy_arns_aws_managed = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = local.use_customer_managed ? local.policy_arns_customer : local.policy_arns_aws_managed
}

module "iam_role_lambda5" {
  source = "../../../modules/iam/lambda5-role"

  role_name   = var.role_name
  role_path   = "/service-role/"
  policy_arns = local.effective_policy_arns
  tags        = var.tags
}

output "role_name" { value = module.iam_role_lambda5.role_name }
output "role_arn"  { value = module.iam_role_lambda5.role_arn  }
