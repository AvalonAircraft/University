data "aws_partition" "current" {}
data "aws_region" "current" {}

############################
# Inputs
############################
variable "role_name" { type = string }                    # bewusst ohne Default
variable "role_path" { type = string, default = "/service-role/" }
variable "tags"      { type = map(string), default = {} }

# Inline policy inputs (parametrisierbar)
variable "bucket_name" { type = string }
variable "kms_key_arn" { type = string }
variable "lambda6_arn" { type = string }
variable "stepfn_arn"  { type = string }

# Guards
variable "role_name" {
  type = string

  validation {
    condition     = length(trim(var.role_name)) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "bucket_name" {
  type = string

  validation {
    condition     = length(trim(var.bucket_name)) > 0
    error_message = "bucket_name darf nicht leer sein."
  }
}

variable "kms_key_arn" {
  type = string

  validation {
    condition     = startswith(var.kms_key_arn, "arn:")
    error_message = "kms_key_arn muss eine gültige ARN sein."
  }
}

variable "lambda6_arn" {
  type = string

  validation {
    condition     = startswith(var.lambda6_arn, "arn:")
    error_message = "lambda6_arn muss eine gültige ARN sein."
  }
}

variable "stepfn_arn" {
  type = string

  validation {
    condition     = startswith(var.stepfn_arn, "arn:")
    error_message = "stepfn_arn muss eine gültige ARN sein."
  }
}


############################
# Trust Policy (Lambda)
############################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["lambda.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}

############################
# Role
############################
resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

############################
# AWS managed policy attachments
############################
# Basic logging etc.
resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ENIs für VPC
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

############################
# Inline Policy 1: Lambda_S3_Secret_Manager_Access
############################
data "aws_iam_policy_document" "lambda_s3_kms_invoke" {
  statement {
    sid     = "S3Access"
    effect  = "Allow"
    actions = ["s3:GetObject","s3:PutObject","s3:DeleteObject"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [var.lambda6_arn]
  }

  statement {
    sid     = "KmsDecryptForS3"
    effect  = "Allow"
    actions = [
      "kms:Decrypt","kms:DescribeKey","kms:Encrypt",
      "kms:ReEncryptFrom","kms:ReEncryptTo",
      "kms:GenerateDataKey","kms:GenerateDataKeyWithoutPlaintext"
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "lambda_s3_kms_invoke" {
  name   = "Lambda_S3_Secret_Manager_Access"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.lambda_s3_kms_invoke.json
}

############################
# Inline Policy 2: StepFunctions (+ S3 + Logs)
############################
data "aws_iam_policy_document" "stepfunctions_plus" {
  statement {
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [var.stepfn_arn]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "stepfunctions_plus" {
  name   = "StepFunctions"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.stepfunctions_plus.json
}

############################
# Outputs
############################
output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn }
