# Module: Lambda6 - URL-Gen & DB-Saving


terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws     = { source = "hashicorp/aws",     version = ">= 5.30.0" }
    archive = { source = "hashicorp/archive", version = ">= 2.4.0" }
  }
}

# --- Environment Data ---
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}
data "aws_partition"       "current" {}


# Inputs


variable "function_name" { type = string }
variable "runtime"       { type = string, default = "python3.13" }
variable "handler"       { type = string, default = "handler.lambda_handler" }

# Code Management
variable "use_archive" { type = bool, default = true }
variable "source_file" { 
  type    = string
  default = "" 
  validation {
    condition     = !var.use_archive || length(var.source_file) > 0
    error_message = "Wenn use_archive=true, muss source_file gesetzt sein."
  }
}
variable "filename" { type = string, default = "" }

# Limits & Storage
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 117 }

# Networking (VPC)
variable "subnet_ids" { 
  type = list(string)
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "VPC-Lambda benötigt mindestens eine Subnet ID."
  }
}
variable "security_group_ids" { type = list(string) }
variable "attach_vpc_access"  { type = bool, default = true }

# Config & Permissions
variable "kms_key_alias"        { type = string, default = "alias/kms-tenant-master-key" }
variable "layer_arns"           { type = list(string), default = [] }
variable "s3_read_bucket_names" { type = list(string), default = ["miraedrive-assets"] }
variable "add_elbv2_describe"   { type = bool, default = true }

variable "api_gateway_ids"              { type = list(string), default = [] }
variable "allow_invoke_from_lambda_arns" { type = list(string), default = [] }

variable "env"  { type = map(string), default = {} }
variable "tags" { type = map(string), default = {} }

variable "role_name_suffix" { type = string, default = "Lambda6-VPC-Role" }
variable "role_path"        { type = string, default = "/service-role/" }


# Locals & Data Sources


data "aws_kms_alias" "env_key" { name = var.kms_key_alias }

locals {
  kms_key_arn    = data.aws_kms_alias.env_key.target_key_arn
  s3_object_arns = [for b in var.s3_read_bucket_names : "arn:${data.aws_partition.current.partition}:s3:::${b}/*"]
}


# IAM Role & Policies


data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = var.role_name_suffix
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

# Standard & VPC Execution Roles
resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  count      = var.attach_vpc_access ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# KMS Access (Inline)
resource "aws_iam_role_policy" "kms_access" {
  name = "LambdaKmsAccess"
  role = aws_iam_role.role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt", "kms:DescribeKey", "kms:Encrypt",
        "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext"
      ]
      Resource = local.kms_key_arn
    }]
  })
}

# S3 Read Access (Inline)
resource "aws_iam_role_policy" "s3_read" {
  count = length(local.s3_object_arns) > 0 ? 1 : 0
  name  = "S3ReadObjects"
  role  = aws_iam_role.role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = local.s3_object_arns
    }]
  })
}

# ELBv2 Describe (Inline)
resource "aws_iam_role_policy" "elbv2_describe" {
  count = var.add_elbv2_describe ? 1 : 0
  name  = "ELBv2Describe"
  role  = aws_iam_role.role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTargetGroups"
      ]
      Resource = "*"
    }]
  })
}


# Log Group & Packaging


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

  ephemeral_storage { size = var.ephemeral_storage_size }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment { variables = var.env }
  layers      = var.layer_arns

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.lg,
    aws_iam_role_policy_attachment.basic_exec,
    aws_iam_role_policy.kms_access
  ]
}


# Invoke Permissions


resource "aws_lambda_permission" "apigw_invoke" {
  for_each      = toset(var.api_gateway_ids)
  statement_id  = "AllowAPIGatewayInvoke-${each.value}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:${data.aws_partition.current.partition}:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${each.value}/*/*/aurora-db"
}

resource "aws_lambda_permission" "lambda_invoke" {
  for_each      = toset(var.allow_invoke_from_lambda_arns)
  statement_id  = "AllowLambdaInvoke-${replace(replace(each.value, ":", "_"), "/", "_")}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.function_name
  principal     = "lambda.amazonaws.com"
  source_arn    = each.value
}


# Outputs


output "lambda_function_arn" { value = aws_lambda_function.fn.arn }
output "lambda_role_arn"     { value = aws_iam_role.role.arn }
