############################
# Module: Lambda5
############################

# --- Inputs ---
variable "function_name" { type = string }                         # z.B. "Lambda5"
variable "runtime"       { type = string, default = "python3.13" }
variable "handler"       { type = string, default = "lambda_function.lambda_handler" }

# Code (genau 1 Variante nutzen)
variable "use_archive" { type = bool,   default = true }
variable "source_file" { type = string, default = "" }             # z.B. ./src/lambda_function.py
variable "filename"    { type = string, default = "" }             # alternativ fertiges ZIP

# Limits
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }
variable "description"            { type = string, default = "Lambda5 function" }

# ENV/Tags
variable "env"  { type = map(string), default = { DEFAULT_CLIENTS = "", STRICT_MODE = "0" } }
variable "tags" { type = map(string), default = {} }

# Rolle (bestehend – wie in der Konsole)
variable "existing_role_name" { type = string, default = "service-role/Lambda5-role-gmx3qmuy" }

# --- Providers/Env ---
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws     = { source = "hashicorp/aws",     version = ">= 5.30.0" }
    archive = { source = "hashicorp/archive", version = ">= 2.4.0" }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}
data "aws_partition"       "current" {}

# --- Validations ---
validation {
  condition     = var.use_archive || length(var.filename) > 0
  error_message = "Entweder 'use_archive=true' ODER ein fertiges ZIP in 'filename' angeben."
}
validation {
  condition     = !var.use_archive || length(var.source_file) > 0
  error_message = "Bei 'use_archive=true' muss 'source_file' gesetzt sein."
}

############################
# Log Group
############################
resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

############################
# Rolle: bestehend (aus Konsole)
############################
data "aws_iam_role" "existing" {
  name = var.existing_role_name
}

############################
# Code-Paket
############################
data "archive_file" "pkg" {
  count       = var.use_archive ? 1 : 0
  type        = "zip"
  source_file = var.source_file
  output_path = "${path.module}/.build/${var.function_name}.zip"
}

locals {
  code_filename    = var.use_archive ? data.archive_file.pkg[0].output_path         : var.filename
  code_source_hash = var.use_archive ? data.archive_file.pkg[0].output_base64sha256 : filebase64sha256(var.filename)
}

############################
# Lambda Function
############################
resource "aws_lambda_function" "fn" {
  function_name = var.function_name
  role          = data.aws_iam_role.existing.arn
  runtime       = var.runtime
  handler       = var.handler
  description   = var.description

  filename         = local.code_filename
  source_code_hash = local.code_source_hash

  memory_size   = var.memory_size
  timeout       = var.timeout
  architectures = ["x86_64"]

  ephemeral_storage { size = var.ephemeral_storage_size }

  environment { variables = var.env }

  depends_on = [aws_cloudwatch_log_group.lg]

  tags = var.tags
}

############################
# Outputs
############################
output "lambda_function_arn" { value = aws_lambda_function.fn.arn }
output "lambda_role_arn"     { value = data.aws_iam_role.existing.arn }
