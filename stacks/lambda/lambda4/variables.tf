variable "region" { type = string, default = "us-east-1" }

# Funktion
variable "function_name" { type = string, default = "Lambda4" }
variable "runtime"       { type = string, default = "python3.13" }
variable "handler"       { type = string, default = "lambda_function.handler" }
variable "description"   { type = string, default = "Lambda4 function" }

# Code
variable "use_archive" { type = bool,   default = true }
variable "source_file" { type = string, default = "./src/lambda_function.py" }
variable "filename"    { type = string, default = "" }

# Limits
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }

# ENV – passend zu deinem Code
variable "default_status" { type = string, default = "available" }
variable "extra_env"      { type = map(string), default = {} }

# IAM Rolle (bestehend, wie in der Konsole)
variable "existing_role_name" { type = string, default = "service-role/Lambda4-role-0qiscamy" }

# Tags
variable "tags" {
  type = map(string)
  default = {
    Project = "MiraeDrive"
    Stack   = "lambda4"
    TenantID = ""
  }
}
