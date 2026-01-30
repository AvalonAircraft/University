# Module: lambda-base


data "aws_partition"       "current" {}
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}


# Inputs


variable "function_name" { type = string }
variable "runtime"       { type = string }
variable "handler"       { type = string }

variable "use_archive" { 
  type        = bool 
  description = "True: Packt source_file in ein ZIP. False: Erwartet fertiges ZIP in filename."
}

variable "source_file" { 
  type    = string 
  default = ""
}

variable "filename" { 
  type    = string 
  default = ""
}

variable "memory_size"            { type = number }
variable "ephemeral_storage_size" { type = number }
variable "timeout"                { type = number }
variable "description"            { type = string }

variable "env"  { type = map(string) }
variable "tags" { type = map(string) }

variable "role_name_suffix" { type = string }

variable "log_retention_days" { type = number }


# Validations


# Validierung für ZIP-Quelle
variable "zip_source_check" {
  type    = string
  default = "check"
  validation {
    condition     = var.use_archive || (length(var.filename) > 0)
    error_message = "Entweder 'use_archive=true' ODER 'filename' (Pfad zum fertigen ZIP) muss gesetzt sein."
  }
}

# Validierung für Quell-Datei
variable "source_file_check" {
  type    = string
  default = "check"
  validation {
    condition     = !var.use_archive || (length(var.source_file) > 0)
    error_message = "Wenn 'use_archive=true' gewählt ist, muss 'source_file' definiert sein."
  }
}


# IAM: Trust + Role + BasicExec


data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals { 
      type        = "Service" 
      identifiers = ["lambda.amazonaws.com"] 
    }
    actions = ["sts:AssumeRole"]
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


# CloudWatch Logs


resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}


# Code-Paket


data "archive_file" "pkg" {
  count       = var.use_archive ? 1 : 0
  type        = "zip"
  source_file = var.source_file
  output_path = "${path.module}/.build/${var.function_name}.zip"
}

locals {
  code_filename    = var.use_archive ? data.archive_file.pkg[0].output_path     : var.filename
  code_source_hash = var.use_archive ? data.archive_file.pkg[0].output_base64sha256 : filebase64sha256(var.filename)
}


# Lambda Function


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

  ephemeral_storage { 
    size = var.ephemeral_storage_size 
  }

  environment { 
    variables = var.env 
  }

  # CloudWatch LogGroup muss existieren, bevor die Lambda das erste Mal loggt
  depends_on = [
    aws_cloudwatch_log_group.lg,
    aws_iam_role_policy_attachment.basic_exec
  ]

  tags = var.tags
}


# Outputs


output "lambda_function_arn" { value = aws_lambda_function.fn.arn }
output "lambda_role_arn"     { value = aws_iam_role.role.arn }
output "lambda_role_name"    { value = aws_iam_role.role.name }
