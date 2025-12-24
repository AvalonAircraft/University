############################################
# Environment (account/region/partition)
############################################
data "aws_caller_identity" "current" {}
data "aws_region"          "current" {}
data "aws_partition"       "current" {}

############################################
# Inputs
############################################
variable "function_name" { type = string }
variable "runtime"       { type = string }
variable "handler"       { type = string }

# Code-Quelle
variable "use_archive" { type = bool   , default = true }
variable "source_file" { type = string , default = "./src/lambda_function.py" } # wird gezippt, wenn use_archive=true
variable "filename"    { type = string , default = "" }                         # fertiges ZIP, wenn use_archive=false

# Resourcen
variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }
variable "log_retention_days"     { type = number, default = 14 }

# anstelle fixer ARNs — portable Eingaben:
variable "kms_key_alias" {
  description = "KMS alias for env vars encryption (e.g. alias/kms-tenant-master-key)"
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
  default = { Project = "MiraeDrive", Stack = "lambda" }
}

############################################
# Validations
############################################
validation {
  condition     = var.use_archive || (length(var.filename) > 0)
  error_message = "Wenn use_archive=false ist, muss 'filename' auf ein gültiges ZIP verweisen."
}

############################################
# KMS-Key via Alias → echte Key-ARN
############################################
data "aws_kms_alias" "env_key" {
  name = var.kms_key_alias
}

############################################
# Locals
############################################
locals {
  kms_key_arn       = data.aws_kms_alias.env_key.target_key_arn
  state_machine_arn = "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.state_machine_name}"
}

############################################
# IAM Trust
############################################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["lambda.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.function_name}-${var.role_name_suffix}"
  path               = "/service-role/"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

# CloudWatch Logs (AWS Managed Policy)
resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# KMS – typische 7 Aktionen, auf den dynamischen Key
resource "aws_iam_role_policy" "kms_access" {
  name = "LambdaKmsAccess"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "kms:Decrypt","kms:DescribeKey","kms:Encrypt",
        "kms:ReEncryptFrom","kms:ReEncryptTo",
        "kms:GenerateDataKey","kms:GenerateDataKeyWithoutPlaintext"
      ],
      Resource = local.kms_key_arn
    }]
  })
}

# Step Functions – StartExecution auf die dynamisch gebaute ARN
resource "aws_iam_role_policy" "stepfunctions_invoke" {
  name = "LambdaStartStepFunction"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["states:StartExecution"],
      Resource = local.state_machine_arn
    }]
  })
}

############################################
# Logging
############################################
resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

############################################
# Packaging (optional)
############################################
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

############################################
# Lambda Function
############################################
resource "aws_lambda_function" "fn" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_role.arn
  runtime       = var.runtime
  handler       = var.handler

  filename         = local.code_filename
  source_code_hash = local.code_source_hash

  memory_size = var.memory_size
  timeout     = var.timeout
  kms_key_arn = local.kms_key_arn

  ephemeral_storage { size = var.ephemeral_storage_size }

  environment {
    variables = {
      STATE_MACHINE_ARN = local.state_machine_arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lg,
    aws_iam_role_policy_attachment.basic_exec,
    aws_iam_role_policy.kms_access,
    aws_iam_role_policy.stepfunctions_invoke
  ]

  tags = var.tags
}

############################################
# Outputs
############################################
output "lambda_function_arn" { value = aws_lambda_function.fn.arn }
output "lambda_role_arn"     { value = aws_iam_role.lambda_role.arn }
