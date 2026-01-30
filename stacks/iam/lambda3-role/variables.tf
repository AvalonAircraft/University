variable "region" {
  type    = string
  default = "us-east-1"
}

variable "role_name" {
  type    = string
  default = "Lambda3-role-7t5id6pm"
}

variable "role_path" {
  type    = string
  default = "/service-role/"
}

variable "bucket_name" {
  type    = string
  default = "miraedrive-assets"
}

# PORTABLE DEFAULT: im Professor-Account gibt es deine Customer-Policies nicht
variable "use_customer_managed" {
  type    = bool
  default = false
}

# Nur relevant wenn use_customer_managed = true
variable "customer_basic_logs_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy (Klon von AWSLambdaBasicExecutionRole)"
  default     = "AWSLambdaBasicExecutionRole-702c2e05-7e66-486b-9ef8-4b1c12bb7d66"
}

variable "customer_vpc_access_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy (Klon von AWSLambdaVPCAccessExecutionRole)"
  default     = "AWSLambdaVPCAccessExecutionRole-876f699d-a632-4f23-be58-2b0bc68ea401"
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
