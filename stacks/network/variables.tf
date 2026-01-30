# Basics

variable "region"     { type = string, default = "us-east-1" }
variable "name"       { type = string, default = "Projekt-vpc" }
variable "cidr_block" { type = string, default = "10.0.0.0/16" }

variable "create_ipv6" { type = bool, default = true }


# AZs (portable)
# Empfehlung: NICHT hardcoden (AZ letter mapping ist account-spezifisch)

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_a_default = data.aws_availability_zones.available.names[0]
  az_b_default = data.aws_availability_zones.available.names[1]
}

variable "az_a" {
  type    = string
  default = ""
  description = "Optional: specific AZ name. Leave empty to auto-pick."
}

variable "az_b" {
  type    = string
  default = ""
  description = "Optional: specific AZ name. Leave empty to auto-pick."
}

# Convenience locals (nutzt Default wenn leer)
locals {
  az_a = var.az_a != "" ? var.az_a : local.az_a_default
  az_b = var.az_b != "" ? var.az_b : local.az_b_default
}


# Subnets

variable "public1_cidr"  { type = string, default = "10.0.0.0/20" }
variable "public2_cidr"  { type = string, default = "10.0.16.0/20" }
variable "private1_cidr" { type = string, default = "10.0.128.0/20" }
variable "private2_cidr" { type = string, default = "10.0.144.0/20" }


# NAT + IPv6 egress

variable "create_nat_gw"          { type = bool, default = true }
variable "create_egress_only_igw" { type = bool, default = true }

# Konsistenz: EIGW macht nur Sinn mit IPv6
variable "create_egress_only_igw_guard" {
  type    = bool
  default = true
  validation {
    condition     = !(var.create_egress_only_igw && !var.create_ipv6)
    error_message = "create_egress_only_igw=true requires create_ipv6=true."
  }
}


# Endpoints (region-dynamisch)

variable "create_s3_gateway_endpoint" { type = bool, default = true }

variable "interface_endpoints" {
  type = list(string)
  default = []
  description = "Optional override. Leave empty to use sane defaults for var.region."
}

locals {
  interface_endpoints_default = [
    "com.amazonaws.${var.region}.lambda",
    "com.amazonaws.${var.region}.secretsmanager",
    "com.amazonaws.${var.region}.ecr.api",
    "com.amazonaws.${var.region}.ecr.dkr",
    "com.amazonaws.${var.region}.logs",
    "com.amazonaws.${var.region}.kms",
    "com.amazonaws.${var.region}.events",
    # Optional (nur wenn du sie wirklich nutzt)
    "com.amazonaws.${var.region}.bedrock-runtime",
    "com.amazonaws.${var.region}.comprehend",
  ]

  interface_endpoints_effective = length(var.interface_endpoints) > 0
    ? var.interface_endpoints
    : local.interface_endpoints_default
}

variable "vpce_security_group_ingress_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/16"]
  description = "Ingress CIDRs allowed to reach VPC interface endpoints SG."
}


# VPCE/Lambda SG Ingress CIDRs
# WICHTIG: NICHT AWS Public IP ranges hardcoden.

variable "lambda_vpce_ingress_cidrs" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "Ingress CIDRs for Lambda-related endpoint SGs. Use VPC CIDR or private subnets."
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
