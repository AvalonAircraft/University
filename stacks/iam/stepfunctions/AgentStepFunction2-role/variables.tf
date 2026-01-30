# Region

variable "region" {
  type    = string
  default = "us-east-1"
}


# Role

# Kein GUID-Suffix im Default – portable & reproduzierbar
variable "role_name" {
  type    = string
  default = "StepFunctions-AgentStepFunction2-role"
}

# Pfad als Variable (statt hardcoded), damit du überall konsistent bist
variable "role_path" {
  type    = string
  default = "/service-role/"
}


# Allowed Lambda Resources

# NOTE:
# - Das ist "breit" (Lambda:* etc.). Funktioniert, ist aber weniger least-privilege.
# - Für echte Portabilität über mehrere Accounts: per tfvars überschreiben.
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


# CloudWatch Log Groups (StepFunctions Logging)

variable "log_group_arns" {
  type = list(string)
  default = [
    "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/states/AgentStepFunction2-Logs:*"
  ]
}


# Policy Strategy

variable "create_managed_policies" {
  type    = bool
  default = true
}

variable "existing_managed_policy_arns" {
  type    = list(string)
  default = []
}


# Tags

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID        = ""
  }
}
