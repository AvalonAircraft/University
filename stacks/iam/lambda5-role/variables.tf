variable "region" {
  type    = string
  default = "us-east-1"
}

variable "role_name" {
  type    = string
  default = "Lambda5-role-gmx3qmuy"
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
  default     = "AWSLambdaBasicExecutionRole-0d5c5f13-6de7-4df6-9414-672fb66dd47c"
}

variable "customer_vpc_access_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy (Klon von AWSLambdaVPCAccessExecutionRole)"
  default     = "AWSLambdaVPCAccessExecutionRole-02e28b66-c82c-4a09-b5a5-1e3bceb961b8"
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
