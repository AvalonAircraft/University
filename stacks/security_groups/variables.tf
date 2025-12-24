variable "region"        { type = string, default = "us-east-1" }
variable "vpc_id"        { type = string }          # z.B. aus module.vpc.vpc_id
variable "private1_cidr" { type = string }          # 10.0.128.0/20
variable "private2_cidr" { type = string }          # 10.0.144.0/20

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID = ""
  }
}

variable "lambda_vpce_ingress_cidrs" {
  type = list(string)
  default = [
    "3.218.0.0/15", "18.204.0.0/14", "52.90.0.0/15",
    "54.152.0.0/16", "54.160.0.0/16", "54.172.0.0/15", "54.174.0.0/15",
    "54.196.0.0/15", "54.198.0.0/16", "54.204.0.0/15", "54.208.0.0/15",
    "54.236.0.0/15", "54.242.0.0/15", "54.210.0.0/15"
  ]
}
