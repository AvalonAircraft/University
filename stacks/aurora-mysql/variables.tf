variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

# aus deinem Network-Stack (Private Subnets) + SG
variable "subnet_private1_id" {
  type        = string
  description = "Private subnet ID #1 (e.g. subnet-...)"
}

variable "subnet_private2_id" {
  type        = string
  description = "Private subnet ID #2 (e.g. subnet-...)"
}

variable "sg_aurora_id" {
  type        = string
  description = "Security Group ID for Aurora (e.g. sg-...)"
}

# Aurora-Cluster
variable "name" {
  type        = string
  description = "Aurora cluster identifier/name"
  default     = "university-aurora"
}

variable "engine_version" {
  type        = string
  description = "Aurora MySQL engine version"
  default     = "8.0.mysql_aurora.3.08.2"
}

# Monitoring & Performance Insights
# --> professor-sicher: NICHT hardcodieren, weil Role evtl. nicht existiert.
variable "monitoring_role_arn" {
  type        = string
  description = "Optional: ARN of existing RDS Enhanced Monitoring role. Leave empty if not used."
  default     = ""
}

# Alternative: per Role-Name auflösen (optional)
variable "monitoring_role_name" {
  type        = string
  description = "Optional: Name of existing RDS Enhanced Monitoring role to look up. Leave empty if not used."
  default     = ""
}

variable "pi_kms_key_id" {
  type        = string
  description = "Optional: KMS Key ID/ARN/alias for Performance Insights (e.g. alias/aws/rds). Leave empty to disable/pass null."
  default     = "alias/aws/rds"
}

# Optionen
variable "deletion_protection" {
  type        = bool
  description = "Deletion protection (set true for prod; default false so professor can destroy)"
  default     = false
}

variable "backup_retention_days" {
  type        = number
  description = "Backup retention in days"
  default     = 7
}

# Serverless v2 ACUs
variable "serverless_min_acu" {
  type        = number
  description = "Aurora Serverless v2 min ACU"
  default     = 0.5
}

variable "serverless_max_acu" {
  type        = number
  description = "Aurora Serverless v2 max ACU"
  default     = 64
}

# AZ Präferenzen (optional)
# -> leer lassen = Modul/Provider kann entscheiden
variable "writer_az" {
  type        = string
  description = "Optional: preferred AZ for writer (e.g. us-east-1a). Leave empty to auto."
  default     = ""
}

variable "reader_az" {
  type        = string
  description = "Optional: preferred AZ for reader (e.g. us-east-1b). Leave empty to auto."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default = {
    Project     = "University"
    Environment = "Dev"
    TenantID    = ""
  }
}
