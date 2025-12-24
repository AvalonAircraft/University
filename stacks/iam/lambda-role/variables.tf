data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region" { type = string, default = "us-east-1" }

# Rolle
variable "role_name" {
  type    = string
  default = "Lambda-role-7zfomm5t"
}

# Ressourcen (meine Defaults)
variable "bucket_name" {
  type    = string
  default = "miraedrive-assets"
}

variable "kms_key_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/mrk-3e9cc314f44947ffb7abb50e39434caa"
}

variable "lambda6_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda6_URL-Gen_DB_Saving_SQL-Query"
}

variable "stepfn_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:StepFunction3_EmailWorkFLow"
}

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "IAM"
    TenantID = ""
  }
}
