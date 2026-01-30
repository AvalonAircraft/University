# Module: Generic-Lambda-EB-VPC


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0.0" }
    archive = { source = "hashicorp/archive", version = ">= 2.0.0" }
  }
}


# Variablen


variable "function_name" { type = string }
variable "runtime"       { type = string, default = "python3.12" }
variable "handler"       { type = string, default = "lambda_function.lambda_handler" }

variable "use_archive" { 
  type    = bool
  default = false 
}

variable "source_file" { 
  type    = string
  default = "" 
}

variable "filename" { 
  type    = string
  default = "" 
}

variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }
variable "env"                    { type = map(string), default = {} }
variable "tags"                   { type = map(string), default = {} }

# VPC
variable "subnet_ids"         { type = list(string), default = [] }
variable "security_group_ids" { type = list(string), default = [] }
variable "attach_vpc_access"  { type = bool, default = false }

# EventBridge-Bus
variable "event_bus_name" { 
  type        = string
  default     = "" 
  description = "Name des Busses. Wenn leer, wird keine PutEvents-Berechtigung erstellt."
}

# Rollen-Konfiguration
variable "role_name_suffix" { type = string, default = "" }
variable "role_path"        { type = string, default = "/service-role/" }


# Umgebung & Locals


data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

locals {
  role_name = var.role_name_suffix != "" ? var.role_name_suffix : "${var.function_name}-role"

  event_bus_arn = var.event_bus_name == "" ? null : "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/${var.event_bus_name}"
  
  # Hilfsvariable für Deployment-Quelle
  code_filename = var.use_archive ? data.archive_file.pkg[0].output_path : var.filename
  code_hash     = var.use_archive ? data.archive_file.pkg[0].output_base64sha256 : filebase64sha256(var.filename)
}


# IAM: Rolle & Policies


data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  count      = var.attach_vpc_access ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "eventbridge_put_strict" {
  count = local.event_bus_arn == null ? 0 : 1
  name  = "${var.function_name}-eb-put"
  role  = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["events:PutEvents"]
      Resource = local.event_bus_arn
    }]
  })
}


# CloudWatch & Packaging


resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
  tags               = var.tags
}

data "archive_file" "pkg" {
  count       = var.use_archive ? 1 : 0
  type        = "zip"
  source_file = var.source_file
  output_path = "${path.module}/.build/${var.function_name}.zip"
}


# Lambda-Funktion


resource "aws_lambda_function" "fn" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn
  runtime       = var.runtime
  handler       = var.handler

  filename         = local.code_filename
  source_code_hash = local.code_hash

  memory_size = var.memory_size
  timeout     = var.timeout

  ephemeral_storage { size = var.ephemeral_storage_size }

  dynamic "vpc_config" {
    for_each = var.attach_vpc_access ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  environment { variables = var.env }

  depends_on = [
    aws_cloudwatch_log_group.lg,
    aws_iam_role_policy_attachment.basic_exec
  ]

  tags = var.tags
}


# Outputs


output "lambda_function_arn" { value = aws_lambda_function.fn.arn }
output "lambda_role_arn"     { value = aws_iam_role.this.arn }
