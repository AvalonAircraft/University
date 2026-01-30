variable "region" {
  type    = string
  default = "us-east-1"
}

variable "role_name" {
  type    = string
  default = "Lambda1-role-8af9qr61"
}

variable "role_path" {
  type    = string
  default = "/service-role/"
}

# PORTABLE DEFAULT: im Professor-Account existieren deine Customer-Policies nicht
variable "use_customer_managed" {
  type    = bool
  default = false
}

# Nur relevant, wenn use_customer_managed = true
variable "customer_basic_logs_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy, die AWSLambdaBasicExecutionRole klont"
  default     = "AWSLambdaBasicExecutionRole-19f3774a-feed-4738-a92a-0e606475c69f"
}

variable "customer_vpc_access_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy, die AWSLambdaVPCAccessExecutionRole klont"
  default     = "AWSLambdaVPCAccessExecutionRole-f9e69a35-784a-430f-a292-97a4fe676e3e"
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
