data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

variable "region" { type = string, default = "us-east-1" }

# Kein GUID-Suffix im Default – so kann ich die Rolle in jedem Account deployen,
# ohne Namenskollisionen mit vorhandenen, konsolen-erzeugten Rollen
variable "role_name" {
  type    = string
  default = "StepFunctions-AgentStepFunction2-role"
}

# Erlaubte Lambdas (meine Liste, aber aus Partition/Region/Account zusammengesetzt)
variable "lambda_resources" {
  type = list(string)
  default = [
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda:*",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda6_URL-Gen_DB_Saving_SQL-Query:*",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda1:*",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda2:*",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda3:*",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda4:*",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda5:*"
  ]
}

# LogGroup-ARNs: Express State Machines brauchen Logs – ich parametriere das
variable "log_group_arns" {
  type = list(string)
  default = [
    "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/states/AgentStepFunction2-Logs:*"
  ]
}

# Schalter für Policy-Erstellung im Modul
variable "create_managed_policies" {
  type    = bool
  default = true
}

# Falls ich stattdessen zentral verwaltete Policies anhängen will
variable "existing_managed_policy_arns" {
  type    = list(string)
  default = []
  # Beispiel:
  # default = [
  #   "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Central-StepFn-Logs",
  #   "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Central-StepFn-LambdaInvoke",
  #   "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/Central-StepFn-XRay"
  # ]
}

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID = ""
  }
}
