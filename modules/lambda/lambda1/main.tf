############################
# Inputs (werden vom Stack gesetzt)
############################
variable "function_name" { type = string }
variable "runtime"       { type = string }
variable "handler"       { type = string }

# Code: entweder auto-packen aus 1 Datei ODER fertiges ZIP
variable "use_archive" { type = bool }
variable "source_file" { type = string }
variable "filename"    { type = string }

# Limits
variable "memory_size"            { type = number }
variable "ephemeral_storage_size" { type = number }
variable "timeout"                { type = number }
variable "description"            { type = string }

# ENV & Tags
variable "env"  { type = map(string) }
variable "tags" { type = map(string) }

# Rollenname (replizierbar, kein Account-Hardcode)
variable "role_name_suffix" { type = string }

# Log-Retention
variable "log_retention_days" { type = number }

############################
# Umgebung
############################
data "aws_partition"       "current" {}
data "aws_caller_identity" "current" {}
data "aws_region"          "current"  {}

############################
# Validations
############################
# Entweder use_archive=true ODER filename (fertiges ZIP) muss gesetzt sein
validation {
  condition     = var.use_archive || (length(var.filename) > 0)
  error_message = "Entweder 'use_archive=true' ODER 'filename' (fertiges ZIP) muss gesetzt sein."
}
# Wenn Archivierung genutzt wird, muss source_file gesetzt sein
validation {
  condition     = !var.use_archive || (length(var.source_file) > 0)
  error_message = "Wenn 'use_archive=true', muss 'source_file' auf die Quell-Datei zeigen."
}

############################
# IAM: Trust + Role + BasicExec
############################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["lambda.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role" {
  name               = var.role_name_suffix
  path               = "/service-role/"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

############################
# CloudWatch Logs
############################
resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
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
  role          = aws_iam_role.role.arn
  runtime       = var.runtime
  handler       = var.handler

  filename         = local.code_filename
  source_code_hash = local.code_source_hash

  description = var.description
  memory_size = var.memory_size
  timeout     = var.timeout

  ephemeral_storage { size = var.ephemeral_storage_size }

  environment { variables = var.env }

  depends_on = [
    aws_cloudwatch_log_group.lg,
    aws_iam_role_policy_attachment.basic_exec
  ]

  tags = var.tags
}

############################
# Outputs
############################
output "lambda_function_arn" { value = aws_lambda_function.fn.arn }
output "lambda_role_arn"     { value = aws_iam_role.role.arn }
