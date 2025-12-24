variable "region"     { type = string, default = "us-east-1" }
variable "name"       { type = string, default = "Projekt-vpc" }
variable "cidr_block" { type = string, default = "10.0.0.0/16" }

variable "create_ipv6" { type = bool, default = true }

variable "az_a" { type = string, default = "us-east-1a" }
variable "az_b" { type = string, default = "us-east-1b" }

variable "public1_cidr"  { type = string, default = "10.0.0.0/20" }
variable "public2_cidr"  { type = string, default = "10.0.16.0/20" }
variable "private1_cidr" { type = string, default = "10.0.128.0/20" }
variable "private2_cidr" { type = string, default = "10.0.144.0/20" }

# NAT + EIGW wie zuvor
variable "create_nat_gw"          { type = bool, default = true }
variable "create_egress_only_igw" { type = bool, default = true }

# Endpoints
variable "create_s3_gateway_endpoint" { type = bool, default = true }
variable "interface_endpoints" {
  type = list(string)
  default = [
    "com.amazonaws.us-east-1.lambda",
    "com.amazonaws.us-east-1.secretsmanager",
    "com.amazonaws.us-east-1.ecr.api",
    "com.amazonaws.us-east-1.ecr.dkr",
    "com.amazonaws.us-east-1.logs",
    "com.amazonaws.us-east-1.kms",
    "com.amazonaws.us-east-1.bedrock-runtime",
    "com.amazonaws.us-east-1.comprehend",
    "com.amazonaws.us-east-1.events",
  ]
}
variable "vpce_security_group_ingress_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

# neu: durchreichen an SG-Modul (kannst man auch leer lassen, dann nutzt das SG-Modul seine Defaults)
variable "lambda_vpce_ingress_cidrs" {
  type = list(string)
  default = [
    "3.218.0.0/15", "18.204.0.0/14", "52.90.0.0/15",
    "54.152.0.0/16", "54.160.0.0/16", "54.172.0.0/15", "54.174.0.0/15",
    "54.196.0.0/15", "54.198.0.0/16", "54.204.0.0/15", "54.208.0.0/15",
    "54.236.0.0/15", "54.242.0.0/15", "54.210.0.0/15"
  ]
}

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID = ""
  }
}
