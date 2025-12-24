data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Umschalter:
  #   true  -> ich verwende meine kundenverwalteten Kopien (falls im Account vorhanden)
  #   false -> ich falle auf AWS-verwaltete Policies zurück (immer verfügbar, account-agnostisch)
  use_customer_managed = var.use_customer_managed

  policy_arns_customer = [
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaBasicExecutionRole-4d5ec943-0a1e-455c-981e-113cc09da8a8",
    "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/AWSLambdaVPCAccessExecutionRole-abad322e-b478-4ac9-a296-28c648a6690d",
  ]

  policy_arns_aws_managed = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]

  effective_policy_arns = local.use_customer_managed ? local.policy_arns_customer : local.policy_arns_aws_managed
}

module "iam_role_Lambda4" {
  source = "../../../modules/iam/lambda4-role"

  role_name   = var.role_name
  role_path   = "/service-role/"
  policy_arns = local.effective_policy_arns
  tags        = var.tags
}

output "role_name" { value = module.iam_role_Lambda4.role_name }
output "role_arn"  { value = module.iam_role_Lambda4.role_arn  }
