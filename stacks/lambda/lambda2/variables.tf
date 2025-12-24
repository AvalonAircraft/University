variable "region" { type = string, default = "us-east-1" }

# Funktion
variable "function_name" { type = string, default = "Lambda2" }
variable "runtime"       { type = string, default = "python3.12" }
variable "handler"       { type = string, default = "lambda_function.lambda_handler" }

# Code (auto packen aus einer Datei – alternativ filename für fertiges ZIP)
variable "use_archive" { type = bool,   default = true }
variable "source_file" { type = string, default = "./src/lambda_function.py" }
variable "filename"    { type = string, default = "" }

# Limits / Settings (wie Konsole)
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }
variable "description"            { type = string, default = "Lambda2 function" }
variable "log_retention_days"     { type = number, default = 14 }

# ENV (aus meiner Konsole)
variable "env" {
  type = map(string)
  default = {
    BEDROCK_EMBED_MODEL_ID = "amazon.titan-embed-text-v2:0"
  }
}

# Bedrock Model-ID (für die IAM-Policy)
variable "bedrock_model_id" {
  type    = string
  default = "amazon.titan-embed-text-v2:0"
}

# VPC (falls Lambda2 in VPC laufen soll → hier true + IDs setzen)
variable "attach_vpc_access"  { type = bool, default = false }
variable "subnet_ids"         { type = list(string), default = [] }
variable "security_group_ids" { type = list(string), default = [] }

# Rolle
variable "role_name_suffix" { type = string, default = "Lambda2-role-5gqtj7be" }

# Tags
variable "tags" {
  type = map(string)
  default = { Project = "MiraeDrive", Stack = "lambda2", TenantID = "" }
}
