variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID (z.B. aus network/vpc stack outputs)"
}

variable "private1_cidr" {
  type        = string
  description = "CIDR des privaten Subnetzes 1 (z.B. 10.0.128.0/20)"
}

variable "private2_cidr" {
  type        = string
  description = "CIDR des privaten Subnetzes 2 (z.B. 10.0.144.0/20)"
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

# OPTIONAL Override:
# - Wenn null -> wir nutzen im main.tf automatisch private1/2 CIDRs
# - Wenn gesetzt -> wir nutzen deine Liste
variable "lambda_vpce_ingress_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach Lambda VPC endpoint SG ingress. If null, defaults to the private subnet CIDRs."
  default     = null
  nullable    = true
}

# Optional: falls dein security-groups Modul IPv6-Handling unterstützt
variable "enable_ipv6_ingress" {
  type        = bool
  description = "Enable IPv6 ingress rules where supported."
  default     = false
}
