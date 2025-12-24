variable "region"    { type = string, default = "us-east-1" }
variable "role_name" { type = string, default = "LambdaAgentHandler-role-cix4b1aj" }

# Optional: falls ich *kundenverwaltete* Policies anhängen will (statt AWS-managed),
# kann ich sie hier übergeben; leer lassen = AWS-managed Defaults (portabel).
variable "policy_arns_override" {
  description = "Liste von Policy-ARNs, die an die Rolle angehängt werden sollen. Leer lassen, um AWS-managed Defaults zu nutzen."
  type        = list(string)
  default     = []
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
