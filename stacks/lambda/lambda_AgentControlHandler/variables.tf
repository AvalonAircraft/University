############################
# Allgemein
############################
variable "region" {
  type    = string
  default = "us-east-1"
}

############################
# Lambda Settings
############################
variable "function_name" { type = string, default = "AgentControlHandler" }
variable "runtime"       { type = string, default = "python3.12" }
variable "handler"       { type = string, default = "handler.lambda_handler" }

# Codequelle: genau eine Variante nutzen (auto-packen ODER fertiges ZIP)
variable "use_archive" { type = bool,   default = true }                 # true => packe source_file automatisch
variable "source_file" { type = string, default = "./src/handler.py" }   # z.B. einzelnes .py
variable "filename"    { type = string, default = "" }                   # alternativ: fertiges ZIP

# Limits
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 60 }

############################
# Umgebung / ENV
############################
variable "env" {
  type = map(string)
  default = {
    # DEFAULT_NLB_HOSTS wird in main.tf dynamisch aus NLB-DNS gebaut
    DEFAULT_NLB_PATH = "/ingest/email"
    NLB_PORT         = "8080"
    NLB_SHEME        = "http"
  }
}

############################
# Lookup-Eingaben (NAMEN statt IDs)
############################
# VPC
variable "vpc_name" {
  type        = string
  description = "Name-Tag der Ziel-VPC (z.B. 'Projekt-vpc')"
  default     = "Projekt-vpc"
}

# Private Subnets
variable "subnet_private1_name" {
  type        = string
  description = "Name-Tag des ersten Private-Subnets (z.B. 'Projekt-subnet-private1-us-east-1a')"
  default     = "Projekt-subnet-private1-us-east-1a"
}
variable "subnet_private2_name" {
  type        = string
  description = "Name-Tag des zweiten Private-Subnets (z.B. 'Projekt-subnet-private2-us-east-1b')"
  default     = "Projekt-subnet-private2-us-east-1b"
}

# Security Groups
variable "sg_lambda_ctrl_name" {
  type        = string
  description = "Name der Lambda-SG (z.B. 'Lambda_AgentControlHandler')"
  default     = "Lambda_AgentControlHandler"
}
variable "sg_lambda_vpce_name" {
  type        = string
  description = "Name der SG für Lambda-VPC-Endpunkte (z.B. 'lambda-vpc-endpoint')"
  default     = "lambda-vpc-endpoint"
}

# NLB (für DEFAULT_NLB_HOSTS)
variable "nlb_name" {
  type        = string
  description = "Name des NLB (z.B. 'nlb-fagate-privatelink')"
  default     = "nlb-fagate-privatelink"
}

############################
# VPC-Attach Flag (Lambda in VPC)
############################
variable "attach_vpc_access" { type = bool, default = true }

############################
# KMS / S3 / ELB Rechte (portabel)
############################
variable "kms_key_alias"        { type = string,      default = "alias/kms-tenant-master-key" }
variable "s3_read_bucket_names" { type = list(string), default = ["miraedrive-assets"] }
variable "add_elbv2_describe"   { type = bool,        default = true }

############################
# Rolle / Tags
############################
variable "role_name_suffix" { type = string, default = "AgentControlHandler-role" }

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
