# Region

variable "region" {
  type    = string
  default = "us-east-1"
}


# Role

variable "role_name" {
  type    = string
  default = "LambdaAgentHandler-role"
}

# Path bewusst als Variable, damit du /service-role/ oder / wählen kannst
variable "role_path" {
  type    = string
  default = "/service-role/"
}


# Optional override policies

variable "policy_arns_override" {
  description = "Liste von Policy-ARNs, die an die Rolle angehängt werden sollen. Leer lassen, um AWS-managed Defaults zu nutzen."
  type        = list(string)
  default     = []
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
