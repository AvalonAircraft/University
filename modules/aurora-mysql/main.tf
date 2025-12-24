############################################
# Module: Aurora MySQL (Serverless v2)
############################################

############################
# Inputs
############################
variable "name"                    { type = string }                    # cluster identifier (z.B. "miraedrive")
variable "engine_version"          { type = string }                    # z.B. "8.0.mysql_aurora.3.08.2"
variable "subnet_ids"              { type = list(string) }              # private subnets
variable "vpc_security_group_ids"  { type = list(string) }              # z.B. [sg-06ffcbcb0a9294c90]
variable "monitoring_role_arn"     { type = string, default = null }    # rds-monitoring-role ARN oder null
variable "pi_kms_key_id"           { type = string, default = "alias/aws/rds" } # KMS für Performance Insights
variable "deletion_protection"     { type = bool,   default = true }
variable "backup_retention_days"   { type = number, default = 7 }

# Serverless v2 Min/Max ACU
variable "serverless_min_acu"      { type = number, default = 0.5 }
variable "serverless_max_acu"      { type = number, default = 64 }

# AZ-Pinning für Instances (optional)
variable "writer_az"               { type = string, default = null }    # z.B. "us-east-1b"
variable "reader_az"               { type = string, default = null }    # z.B. "us-east-1b"

# Tags
variable "tags" { type = map(string), default = {} }

############################
# Data
############################
data "aws_region" "current" {}

############################
# Subnet Group
############################
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-subnets" })
}

############################
# Cluster (Aurora MySQL v3 – Serverless v2)
############################
resource "aws_rds_cluster" "this" {
  cluster_identifier                  = var.name
  engine                              = "aurora-mysql"
  engine_mode                         = "provisioned"          # für Serverless v2
  engine_version                      = var.engine_version

  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = var.vpc_security_group_ids

  # Auth & Security
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  kms_key_id                          = "alias/aws/rds"
  deletion_protection                 = var.deletion_protection

  # Admin Credentials via AWS-managed Secret
  manage_master_user_password         = true
  master_username                     = "admin"

  # Backups & Logs
  backup_retention_period             = var.backup_retention_days
  preferred_backup_window             = "06:15-06:45"
  enabled_cloudwatch_logs_exports     = ["error", "general", "slowquery", "audit"]

  # Data API
  enable_http_endpoint                = true

  # Serverless v2 Scaling
  serverlessv2_scaling_configuration {
    min_capacity = var.serverless_min_acu
    max_capacity = var.serverless_max_acu
  }

  tags = merge(var.tags, { Name = var.name })
}

############################
# Instances (1 Writer + 1 Reader)
############################
resource "aws_rds_cluster_instance" "writer" {
  identifier                       = "${var.name}-instance-1"
  cluster_identifier               = aws_rds_cluster.this.id
  instance_class                   = "db.serverless"
  engine                           = aws_rds_cluster.this.engine
  engine_version                   = aws_rds_cluster.this.engine_version
  publicly_accessible              = false
  promotion_tier                   = 1
  performance_insights_enabled     = true
  performance_insights_kms_key_id  = var.pi_kms_key_id
  monitoring_interval              = 60
  monitoring_role_arn              = var.monitoring_role_arn
  db_subnet_group_name             = aws_db_subnet_group.this.name
  availability_zone                = var.writer_az

  tags = merge(var.tags, { Name = "${var.name}-instance-1", Role = "writer" })
}

resource "aws_rds_cluster_instance" "reader" {
  identifier                       = "${var.name}-instance-1-ro"
  cluster_identifier               = aws_rds_cluster.this.id
  instance_class                   = "db.serverless"
  engine                           = aws_rds_cluster.this.engine
  engine_version                   = aws_rds_cluster.this.engine_version
  publicly_accessible              = false
  promotion_tier                   = 15
  performance_insights_enabled     = true
  performance_insights_kms_key_id  = var.pi_kms_key_id
  monitoring_interval              = 60
  monitoring_role_arn              = var.monitoring_role_arn
  db_subnet_group_name             = aws_db_subnet_group.this.name
  availability_zone                = var.reader_az

  tags = merge(var.tags, { Name = "${var.name}-instance-1-ro", Role = "reader" })
}

############################
# Outputs
############################
output "cluster_arn"         { value = aws_rds_cluster.this.arn }
output "cluster_id"          { value = aws_rds_cluster.this.id }
output "cluster_resource_id" { value = aws_rds_cluster.this.cluster_resource_id }

output "endpoint_writer"     { value = aws_rds_cluster.this.endpoint }       # miraedrive.cluster-....rds.amazonaws.com:3306
output "endpoint_reader"     { value = aws_rds_cluster.this.reader_endpoint }

output "db_subnet_group"     { value = aws_db_subnet_group.this.name }
output "instance_writer_id"  { value = aws_rds_cluster_instance.writer.id }
output "instance_reader_id"  { value = aws_rds_cluster_instance.reader.id }
