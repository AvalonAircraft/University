variable "region"               { type = string, default = "us-east-1" }
variable "role_name"            { type = string, default = "Lambda4-role-0qiscamy" }
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
