variable "region" { type = string, default = "us-east-1" }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID = ""
  }
}

# Logging-Optionen
variable "create_error_log_group"  { type = bool,   default = true }
variable "enable_s3_error_logging" { type = bool,   default = true }
variable "include_execution_data"  { type = bool,   default = false }

# S3 Bucket für ERROR-Logs
variable "s3_bucket_name" { type = string, default = "miraedrive-assets" }
