variable "region" {
  type    = string
  default = "us-east-1"
}

variable "role_name" {
  type    = string
  default = "Lambda4-role-0qiscamy"
}

variable "role_path" {
  type    = string
  default = "/service-role/"
}

# PORTABLE DEFAULT: Professor-Account hat deine customer-managed Kopien sehr wahrscheinlich nicht
variable "use_customer_managed" {
  type    = bool
  default = false
}

# Nur relevant wenn use_customer_managed = true
variable "customer_basic_logs_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy (Klon von AWSLambdaBasicExecutionRole)"
  default     = "AWSLambdaBasicExecutionRole-4d5ec943-0a1e-455c-981e-113cc09da8a8"
}

variable "customer_vpc_access_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy (Klon von AWSLambdaVPCAccessExecutionRole)"
  default     = "AWSLambdaVPCAccessExecutionRole-abad322e-b478-4ac9-a296-28c648a6690d"
}

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID        = ""
  }
}
