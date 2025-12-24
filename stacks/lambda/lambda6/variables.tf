data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

variable "region"        { type = string, default = "us-east-1" }

# Funktion
variable "function_name" { type = string, default = "Lambda6_URL-Gen_DB_Saving_SQL-Query" }
variable "runtime"       { type = string, default = "python3.13" }
variable "handler"       { type = string, default = "handler.lambda_handler" }

# Code
variable "use_archive" { type = bool,   default = true }
variable "source_file" { type = string, default = "./src/handler.py" }
variable "filename"    { type = string, default = "" }

# Limits
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 117 }

# Env (aus meiner Konsole)
variable "env" {
  type = map(string)
  default = {
    CONNECT_TIMEOUT         = "30"
    DB_HOST                 = "miraedrive.cluster-col0w04g2rbq.us-east-1.rds.amazonaws.com"
    DB_PORT                 = "3306"
    META_DB_NAME            = "miraedrive_db"
    META_DB_USER            = "admin_miraedrive"
    RDS_CA_PATH             = "/opt/python/rds-combined-ca-bundle.pem"
    READ_TIMEOUT            = "30"
    REGION                  = "us-east-1"
    S3_BUCKET               = "miraedrive-assets"
    S3_PREFIX_TEMPLATE      = "tenants/{tenant_id}/emails/"
    SES_IDENTITY_PREFIX     = "tenant-"
    TENANT_DB_USER_TEMPLATE = "tenant_{tenant_id}_app"
    TENANT_SCHEMA_PREFIX    = "tenant_"
    WRITE_TIMEOUT           = "30"
  }
}

# VPC — mit den Outputs meines Network-/SG-Stacks überschreiben
variable "subnet_ids" {
  type    = list(string)
  default = []   # z. B. [module.network.subnet_private1_id, module.network.subnet_private2_id]
}
variable "security_group_ids" {
  type    = list(string)
  default = []   # z. B. [module.security_groups.sg_lambda6_to_vpce_id]
}
variable "attach_vpc_access" { type = bool, default = true }

# KMS & Layer & S3 & ELB
variable "kms_key_alias"        { type = string, default = "alias/kms-tenant-master-key" }
variable "layer_arns"           { type = list(string), default = [
  "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:layer:pymysql-layer:4"
] }
variable "s3_read_bucket_names" { type = list(string), default = ["miraedrive-assets"] }
variable "add_elbv2_describe"   { type = bool, default = true }

# API-Gateway / Lambda-Invoke Permissions
variable "api_gateway_ids" { type = list(string), default = ["tp6ttttrqa"] } # dein GeneralGateway
variable "allow_invoke_from_lambda_arns" { type = list(string), default = [
  "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:Lambda"
]}

# Tags
variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    TenantID          = ""
    Type            = "Lambda"
    Umgebung        = "Produktiv"
  }
}
