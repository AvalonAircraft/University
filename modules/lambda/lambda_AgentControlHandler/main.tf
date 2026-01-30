# Module: Universal-Lambda


data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

# KMS Key via Alias
data "aws_kms_alias" "env_key" {
  name = var.kms_key_alias
}


# Variables


variable "function_name" { type = string }
variable "runtime"       { type = string, default = "python3.12" }
variable "handler"       { type = string, default = "handler.lambda_handler" }

variable "use_archive" { type = bool,   default = true }
variable "source_file" { type = string, default = "" }
variable "filename"    { type = string, default = "" }

variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 60 }
variable "tags"                   { type = map(string), default = {} }

variable "env" { type = map(string), default = {} }

variable "role_name_suffix" { type = string, default = "" }
variable "role_path"        { type = string, default = "/service-role/" }

variable "subnet_ids"         { type = list(string), default = [] }
variable "security_group_ids" { type = list(string), default = [] }
variable "attach_vpc_access"  { type = bool, default = true }

variable "kms_key_alias"        { type = string, default = "alias/kms-tenant-master-key" }
variable "s3_read_bucket_names" { type = list(string), default = ["miraedrive-assets"] }
variable "add_elbv2_describe"   { type = bool, default = true }


# Locals & Validations


locals {
  role_name      = var.role_name_suffix != "" ? var.role_name_suffix : "${var.function_name}-role"
  kms_key_arn    = data.aws_kms_alias.env_key.target_key_arn
  s3_object_arns = [for b in var.s3_read_bucket_names : "arn:${data.aws_partition.current.partition}:s3:::${b}/*"]
  
  # Validierung für VPC-Konfiguration
  vpc_valid = var.attach_vpc_access ? (length(var.subnet_ids) > 0 && length(var.security_group_ids) > 0) : true
}

resource "null_resource" "vpc_check" {
  count = local.vpc_valid ? 0 : "FEHLER: Wenn attach_vpc_access=true, müssen subnet_ids und security_group_ids gesetzt sein!"
}


# IAM: Role & Policies


data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = local.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

# Managed Policies
resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  count      = var.attach_vpc_access ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# KMS Permissions
data "aws_iam_policy_document" "kms_access" {
  statement {
    actions = [
      "kms:Decrypt", "kms:DescribeKey", "kms:Encrypt",
      "kms:ReEncrypt*", "kms:GenerateDataKey*"
    ]
    resources = [local.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "kms_access" {
  name   = "LambdaKmsAccess"
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.kms_access.json
}

# S3 Read
data "aws_iam_policy_document" "s3_read" {
  count = length(local.s3_object_arns) > 0 ? 1 : 0
  statement {
    actions   = ["s3:GetObject"]
    resources = local.s3_object_arns
  }
}

resource "aws_iam_role_policy" "s3_read" {
  count  = length(local.s3_object_arns) > 0 ? 1 : 0
  name   = "S3ReadObjects"
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.s3_read[0].json
}


# CloudWatch & Packaging


resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

data "archive_file" "pkg" {
  count       = var.use_archive ? 1 : 0
  type        = "zip"
  source_file = var.source_file
  output_path = "${path.module}/.build/${var.function_name}.zip"
}

locals {
  code_filename    = var.use_archive ? data.archive_file.pkg[0].output_path : var.filename
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

  memory_size = var.memory_size
  timeout     = var.timeout
  kms_key_arn = local.kms_key_arn

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
output "lambda_role_arn"     { value = aws_iam_role.role.arn }
