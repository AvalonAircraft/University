variable "region"               { type = string, default = "us-east-1" }
variable "role_name"            { type = string, default = "Lambda3-role-7t5id6pm" }
variable "bucket_name"          { type = string, default = "miraedrive-assets" }

# Umschalten zwischen kundenverwaltet (true) und AWS-Managed (false)
variable "use_customer_managed" { type = bool,   default = true }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID = ""
  }
}
