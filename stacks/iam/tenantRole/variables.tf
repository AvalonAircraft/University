# Region

variable "region" {
  type    = string
  default = "us-east-1"
}


# Rolle

variable "role_name" {
  type    = string
  default = "TenantRole"
}

variable "role_path" {
  type    = string
  default = "/"
}


# S3 Bucket

variable "bucket" {
  type    = string
  default = "miraedrive-assets"
}


# Optional: zusätzliche Trust-Principals
# Wenn leer, vertraut der Stack automatisch dem Root des aktuellen Accounts.

variable "trusted_principals" {
  type    = list(string)
  default = []
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
