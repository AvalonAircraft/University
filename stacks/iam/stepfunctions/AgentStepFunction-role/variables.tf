# Region

variable "region" {
  type    = string
  default = "us-east-1"
}


# Role

# Generischer Rollenname (keine zufällige GUID)
variable "role_name" {
  type    = string
  default = "StepFunctions-AgentStepFunction-role"
}

# Pfad als Variable (portabler, je nach Konvention /service-role/ oder /)
variable "role_path" {
  type    = string
  default = "/service-role/"
}


# Lambdas, die die State Machine aufruft

# WICHTIG:
# - In einem anderen Account heißen die Lambdas ggf. anders.
# - Daher solltest du sie im Ziel-Account per tfvars überschreiben.
variable "lambda_arns" {
  type = list(string)
  default = [
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda6_URL-Gen_DB_Saving_SQL-Query"
  ]
}


# CloudWatch LogGroups für StepFunctions Logging

# WICHTIG:
# - LogGroup-Namen sind in anderen Accounts oft anders.
# - Daher idealerweise im Ziel-Account per tfvars überschreiben.
variable "log_group_arns" {
  type = list(string)
  default = [
    "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/states/MyStateMachine-Logs:*"
  ]
}


# Policy Strategy

# true  => Modul erstellt Managed Policies selbst
# false => Modul hängt nur existing_managed_policy_arns an
variable "create_managed_policies" {
  type    = bool
  default = true
}

# Falls du zentral verwaltete Policies anhängen willst (im Ziel-Account pflegen)
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
