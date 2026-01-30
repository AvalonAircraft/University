# Region

variable "region" {
  type    = string
  default = "us-east-1"
}


# Role

variable "role_name" {
  type    = string
  default = "StepFunctions-StepFunction3_EmailWorkFLow-role"
}

variable "role_path" {
  type    = string
  default = "/service-role/"
}


# Lambda resources (Invoke targets)

# NOTE:
# Für lambda:InvokeFunction sind ARNs mit :* am robustesten (Aliases/Versionen/LATEST).
# Wenn du maximal strict sein willst, gib hier nur die exakten Funktionsnamen an.
variable "lambda_resources" {
  type = list(string)
  default = [
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda6_URL-Gen_DB_Saving_SQL-Query:*",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda:*",
    "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:AgentControlHandler:*"
  ]
}


# Policy strategy

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
