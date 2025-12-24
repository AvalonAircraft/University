data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

variable "region" { type = string, default = "us-east-1" }

# Generischer Rollenname (keine zufällige Suffix-GUID)
variable "role_name" {
  type    = string
  default = "StepFunctions-AgentStepFunction-role"
}

# Lambdas, die die State Machine aufruft
variable "lambda_arns" {
  type = list(string)
  default = [
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda6_URL-Gen_DB_Saving_SQL-Query"
  ]
}

# CloudWatch LogGroups, in die protokolliert wird
variable "log_group_arns" {
  type = list(string)
  default = [
    # passe ggf. an den tatsächlichen LogGroup-Namen deiner State Machine an
    "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/states/MyStateMachine-Logs:*"
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
  #   "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/Central-StepFn-Logs",
  #   "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/Central-StepFn-LambdaInvoke",
  #   "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/Central-StepFn-XRay"
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
