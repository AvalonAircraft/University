variable "region" { type = string, default = "us-east-1" }

# Funktion
variable "function_name" { type = string, default = "Lambda1" }
variable "runtime"       { type = string, default = "python3.12" }
variable "handler"       { type = string, default = "lambda_function.lambda_handler" }

# Code (auto packen aus einer Datei – alternativ filename für fertiges ZIP)
variable "use_archive" { type = bool,   default = true }
variable "source_file" { type = string, default = "./src/lambda_function.py" }
variable "filename"    { type = string, default = "" }

# Limits / Settings (entspricht deiner Konsole)
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }
variable "description"            { type = string, default = "Lambda1 function" }
variable "log_retention_days"     { type = number, default = 14 }

# Env (aus deiner Konsole)
variable "env" {
  type = map(string)
  default = {
    MAX_TEXT_LEN        = "20000"
    REQUIRE_BEDROCK     = "1"
    REQUIRE_META_FIELDS = "subject,from,to"
    STRICT_VALIDATION   = "1"
    TENANT_ALLOWLIST    = ""
    TENANT_BLOCKLIST    = ""
  }
}

# Rolle (eindeutiger Name, replizierbar)
variable "role_name_suffix" { type = string, default = "Lambda1-role" }

# Tags
variable "tags" {
  type = map(string)
  default = { Project = "MiraeDrive", Stack = "lambda1", TenantID = "" }
}
