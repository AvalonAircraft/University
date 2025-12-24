variable "region"        { type = string, default = "us-east-1" }

# Funktion
variable "function_name" { type = string, default = "LambdaAgentHandler" }
variable "runtime"       { type = string, default = "python3.12" }
variable "handler"       { type = string, default = "lambda_function.lambda_handler" }

# Code (auto packen aus einer Datei – alternativ filename für fertiges ZIP)
variable "use_archive" { type = bool,   default = true }
variable "source_file" { type = string, default = "./src/lambda_function.py" }
variable "filename"    { type = string, default = "" }

# Settings
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }

# EventBridge (STRIKT auf diesen Bus)
variable "event_bus_name" { type = string, default = "event-bus-miraedrive" }

# (VPC nur falls benötigt)
variable "attach_vpc_access"  { type = bool, default = false }
variable "subnet_ids"         { type = list(string), default = [] }
variable "security_group_ids" { type = list(string), default = [] }

# Weitere eigene ENV-Vars
variable "env" { type = map(string), default = {} }

# Rollenname (ohne Account-Bezug)
variable "role_name_suffix" { type = string, default = "LambdaAgentHandler-role" }

# Tags
variable "tags" {
  type = map(string)
  default = { Project = "MiraeDrive", Stack = "lambda_agenthandler", TenantID = "" }
}
