data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# ich setze die Region im Provider; diese Variable ist nur Referenz
variable "region" { type = string, default = "us-east-1" }

# bewusste, neutrale Defaults (leer) → ich übergebe je Account/Stage korrekt
variable "role_name"   { type = string, default = "SES_S3_EmailDeliveryRole" }
variable "bucket_name" { type = string }   # kein Default → muss ich setzen
variable "kms_key_arn" { type = string }   # kein Default → muss ich setzen
variable "ses_receipt_rule_arn" { type = string } # kein Default → muss ich setzen

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID = ""
  }
}
