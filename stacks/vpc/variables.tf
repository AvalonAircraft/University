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

# NAT + EIGW
variable "create_nat_gw"          { type = bool, default = true }
variable "create_egress_only_igw" { type = bool, default = true }

# DHCP
variable "create_dhcp_options"      { type = bool,   default = true }
variable "dhcp_domain_name"         { type = string, default = "ec2.internal" }
variable "dhcp_domain_name_servers" { type = list(string), default = ["AmazonProvidedDNS"] }

# Endpoints
variable "create_s3_gateway_endpoint" { type = bool, default = true }

# Wenn null/leer -> werden in main.tf aus var.region automatisch erzeugt
variable "interface_endpoints" {
  type    = list(string)
  default = null
}

# Wenn leer -> Fallback auf [var.cidr_block]
variable "vpce_security_group_ingress_cidrs" {
  type    = list(string)
  default = []
}

# Optional: Flow Logs
variable "enable_flow_logs"        { type = bool,   default = false }
variable "flow_logs_traffic_type"  { type = string, default = "ALL" }
variable "flow_logs_log_group_name"{ type = string, default = null }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID = ""
  }
}
