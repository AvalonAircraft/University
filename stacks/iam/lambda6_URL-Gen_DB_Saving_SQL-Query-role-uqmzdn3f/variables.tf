data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Role

variable "role_name" {
  type    = string
  default = "Lambda6_URL-Gen_DB_Saving_SQL-Query-role-uqmzdn3f"
}

variable "role_path" {
  type    = string
  default = "/service-role/"
}


# Managed Policy Toggle (PORTABLE DEFAULT)

# false = AWS-managed Standard (immer vorhanden, professor-friendly)
# true  = customer-managed (nur wenn im Account vorhanden)
variable "use_customer_managed" {
  type    = bool
  default = false
}

# Nur relevant wenn use_customer_managed = true
variable "customer_basic_logs_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy (Klon von AWSLambdaBasicExecutionRole)"
  default     = "AWSLambdaBasicExecutionRole-add46fc8-c3a5-4517-9fe1-3f09334e9cbb"
}

variable "customer_vpc_access_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy (Klon von AWSLambdaVPCAccessExecutionRole)"
  default     = "AWSLambdaVPCAccessExecutionRole-0fe47f9d-64d9-43d6-a708-f959cb55630f"
}


# S3 / KMS

# Achtung: Bucket-Namen sind global. Im Professor-Account muss das i. d. R. angepasst werden.
variable "s3_bucket" {
  type    = string
  default = "miraedrive-assets"
}

# Entweder direkt ARN setzen...
variable "kms_key_arn" {
  type        = string
  description = "Optional: KMS Key ARN. Leer lassen, um kms_key_alias zu nutzen."
  default     = ""
}

# ...oder portabel via Alias auflösen (empfohlen)
variable "kms_key_alias" {
  type        = string
  description = "Optional: KMS alias, z.B. alias/kms-tenant-master-key"
  default     = "alias/kms-tenant-master-key"
}


# RDS IAM Auth (rds-db:connect)

# Option A: fertige rds-db:connect ARNs (leer lassen wenn Option B genutzt wird)
variable "rds_db_users" {
  type    = list(string)
  default = []
}

# Option B (empfohlen): DBI Resource ID + Usernames
# WICHTIG: Für IAM DB Auth ist das typischerweise die DB INSTANCE Resource ID (dbi-...), nicht cluster-...
# In anderen Accounts ist das immer anders -> daher Default leer (erzwingt saubere Übergabe).
variable "rds_dbi_resource_id" {
  type        = string
  description = "DBI Resource ID (dbi-...), z.B. aus der Aurora-Instance. NICHT cluster-..."
  default     = ""
}

variable "rds_db_usernames" {
  type        = list(string)
  description = "DB Usernames, für die rds-db:connect erlaubt sein soll (wildcards möglich über IAM '*')."
  default = [
    "admin_miraedrive",
    "tenant_*_app"
  ]
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
