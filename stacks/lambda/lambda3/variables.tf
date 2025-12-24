variable "region" { type = string, default = "us-east-1" }

# Funktion
variable "function_name" { type = string, default = "Lambda3" }
variable "runtime"       { type = string, default = "python3.13" }
variable "handler"       { type = string, default = "lambda_function.lambda_handler" }
variable "description"   { type = string, default = "Lambda3 function" }

# Code
variable "use_archive" { type = bool,   default = true }
variable "source_file" { type = string, default = "./src/lambda_function.py" }
variable "filename"    { type = string, default = "" }

# Limits
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }

# ENV – deckt deinen Code & Konsole ab
variable "output_bucket" { type = string, default = "miraedrive-assets" }
variable "cf_domain"     { type = string, default = "www.miraedrive.com" }
variable "folder_name"   { type = string, default = "KI_Results" }  # setzt FOLDER_NAME & PDF_TENANT_SUBFOLDER
variable "root_prefix"   { type = string, default = "" }            # optional
variable "kms_key_id"    { type = string, default = "" }            # optional SSE-KMS

# optionale Feintuning-ENV
variable "ki_results_rolling_limit" { type = number, default = 200 }
variable "presign_expires"          { type = number, default = 600 }
variable "use_presigned"            { type = bool,   default = false }
variable "extra_env"                { type = map(string), default = {} }

# API Gateway Trigger (entspricht deiner Konsole)
variable "api_gateway_ids"   { type = list(string), default = ["tp6ttttrqa"] }
variable "api_resource_path" { type = string,       default = "s3-storage" }
variable "api_methods"       { type = list(string), default = ["GET","PUT","DELETE"] }

# IAM Rolle (bestehend)
variable "existing_role_name" { type = string, default = "service-role/Lambda3-role-7t5id6pm" }

# Tags
variable "tags" {
  type = map(string)
  default = {
    Project = "MiraeDrive"
    Stack   = "lambda3"
    TenantID = ""
  }
}
