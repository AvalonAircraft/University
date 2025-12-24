variable "region" { type = string, default = "us-east-1" }

# Rolle (hier kann ich meinen bekannten Namen vorgeben)
variable "role_name" {
  type    = string
  default = "ecsTaskExecutionRole-ai-agent"
}

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "IAM"
    TenantID = ""
  }
}

# optional: weitere Managed Policies anhängen (i. d. R. leer lassen)
variable "extra_policy_arns" {
  type    = list(string)
  default = []
}
