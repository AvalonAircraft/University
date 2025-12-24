variable "region" { type = string, default = "us-east-1" }

variable "function_name" { type = string, default = "Lambda" }
variable "runtime"       { type = string, default = "python3.12" }
variable "handler"       { type = string, default = "lambda_function.lambda_handler" }

# Code-Quelle
variable "use_archive" { type = bool,   default = true }
variable "source_file" { type = string, default = "./src/lambda_function.py" }
variable "filename"    { type = string, default = "" } # wenn use_archive=false → fertiges ZIP

# Ressourcen
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }
variable "log_retention_days"     { type = number, default = 14 }

# Portable Eingaben
variable "kms_key_alias" {
  description = "KMS alias for the key used by Lambda env vars (e.g. alias/kms-tenant-master-key)"
  type        = string
  default     = "alias/kms-tenant-master-key"
}

variable "state_machine_name" {
  description = "Name der Step Functions State Machine"
  type        = string
  default     = "StepFunction3_EmailWorkFLow"
}

# Rolle
variable "role_name_suffix" { type = string, default = "Lambda-role" }

variable "tags" {
  type    = map(string)
  default = { Project = "MiraeDrive", Stack = "lambda", TenantID = "" }
}
