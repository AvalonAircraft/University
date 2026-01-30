variable "region" {
  type    = string
  default = "us-east-1"
}

# Failsafe: Organizations geht nur im AWS Organizations MANAGEMENT Account.
# Default = false, damit Uni/Professor-Deploy nicht abbricht.
variable "enabled" {
  type    = bool
  default = false
}

variable "ou_core_name" {
  type    = string
  default = "CoreServices"
}

variable "ou_tenants_name" {
  type    = string
  default = "Tenants"
}

# Tag Policy – TenantID Muster
variable "tenant_id_pattern" {
  type    = string
  default = "tenant-*"
}

# Beispiel-Tenants (werden als neue Konten erstellt)
variable "tenants" {
  type = list(object({
    name             = string
    email            = string
    tenant_id        = string
    role_name        = optional(string, "OrganizationAccountAccessRole")
    tags             = optional(map(string), {})
    existing_account = optional(bool, false)
  }))

  default = [
    {
      name      = "AvalonAircraft"
      email     = "ceo@avalonaircraft.com"
      tenant_id = "AvalonAircraft"
      tags      = { Environment = "Prod" }
    }
  ]
}

variable "common_tags" {
  type = map(string)
  default = {
    Project = "MiraeDrive"
    Owner   = "Platform"
  }
}
