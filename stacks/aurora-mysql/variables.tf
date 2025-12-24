data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

variable "region" { type = string, default = "us-east-1" }

# aus deinem Network-Stack (Private Subnets) + SG
variable "subnet_private1_id" { type = string } # z.B. 10.0.128.0/20 Subnet
variable "subnet_private2_id" { type = string } # z.B. 10.0.144.0/20 Subnet
variable "sg_aurora_id"       { type = string } # sg-06ffcbcb0a9294c90

# Aurora-Cluster
variable "name"           { type = string, default = "miraedrive" }
variable "engine_version" { type = string, default = "8.0.mysql_aurora.3.08.2" }

# Monitoring & Performance Insights
variable "monitoring_role_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/rds-monitoring-role"
}
variable "pi_kms_key_id" { type = string, default = "alias/aws/rds" }

# Optionen
variable "deletion_protection"   { type = bool,   default = true }
variable "backup_retention_days" { type = number, default = 7 }

# Serverless v2 ACUs
variable "serverless_min_acu" { type = number, default = 0.5 }
variable "serverless_max_acu" { type = number, default = 64 }

# AZ Präferenzen
variable "writer_az" { type = string, default = "us-east-1b" }
variable "reader_az" { type = string, default = "us-east-1b" }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    Umgebung        = "Produktiv"
    "StartUp-Modus" = "true"
    TenantID = ""
  }
}
