data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region"    { type = string, default = "us-east-1" }
variable "role_name" { type = string, default = "Lambda6_URL-Gen_DB_Saving_SQL-Query-role-uqmzdn3f" }

# S3/KMS (account-agnostisch durch Datenquellen)
variable "s3_bucket" {
  type    = string
  default = "miraedrive-assets"
}

variable "kms_key_arn" {
  type = string
  # Default nutzt aktuell deinen MRK-Key; in anderen Accounts einfach überschreiben.
  default = "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/mrk-3e9cc314f44947ffb7abb50e39434caa"
}

# Option A: fertige rds-db:connect ARNs (leer lassen, wenn Option B genutzt wird)
variable "rds_db_users" {
  type    = list(string)
  default = []
}

# Option B: dynamisch bauen (empfohlen für Replikation)
variable "rds_cluster_resource_id" {
  description = "z.B. cluster-XRHZL2Z7TBEG6JAOKKHN7BAPKI (in JEDEM Account anders!)"
  type        = string
  default     = "cluster-XRHZL2Z7TBEG6JAOKKHN7BAPKI"
}

variable "rds_db_usernames" {
  description = "Usernamen, für die rds-db:connect erlaubt sein soll"
  type        = list(string)
  default     = [
    "admin_miraedrive",
    "tenant_*_app"
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
