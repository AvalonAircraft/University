# Ich halte den Stack bewusst account-agnostisch:
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Kein GUID-Suffix im Namen – so kann ich die Rolle überall reproduzieren
variable "role_name" {
  type    = string
  default = "StepFunctions-StepFunction3_EmailWorkFLow-role"
}

# Die Funktionen, die die State Machine invoken darf – dynamisch aus Partition/Region/Account
variable "lambda_resources" {
  type = list(string)
  default = [
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda6_URL-Gen_DB_Saving_SQL-Query",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:AgentControlHandler",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:AgentControlHandler:*"
  ]
}

# Optional-Schalter für Policy-Erstellung im Modul
variable "create_managed_policies" {
  type    = bool
  default = true
}

variable "existing_managed_policy_arns" {
  type    = list(string)
  default = []
  # Beispiel:
  # default = [
  #   "arn:aws:iam::123456789012:policy/Central-LambdaInvokeScoped",
  #   "arn:aws:iam::123456789012:policy/Central-XRayAccess"
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
