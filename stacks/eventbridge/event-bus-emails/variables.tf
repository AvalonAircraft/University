variable "region"               { type = string, default = "us-east-1" }

# Bus & Rule
variable "bus_name"             { type = string, default = "event-bus-emails" }
variable "rule_name"            { type = string, default = "Email_S3-To_Lambda" }

# S3 Filter
variable "bucket_name"          { type = string, default = "miraedrive-assets" }
variable "key_prefix"           { type = string, default = "emails/" }   # wichtig: mit Slash

# Ziel-Lambda (Name → ARN via Data Source)
variable "lambda_function_name" { type = string, default = "Lambda" }

# Optional: DLQ
variable "dlq_arn"              { type = string, default = "" }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "EventBridge"
    TenantID = ""
  }
}
