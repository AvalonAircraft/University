############################
# Inputs (vom Stack gesetzt)
############################
variable "function_name" { type = string }
variable "runtime"       { type = string }
variable "handler"       { type = string }

# Code: entweder auto-packen aus 1 Datei ODER fertiges ZIP
variable "use_archive" { type = bool }
variable "source_file" { type = string }
variable "filename"    { type = string }

# Limits/Settings
variable "memory_size"            { type = number }
variable "ephemeral_storage_size" { type = number }
variable "timeout"                { type = number }
variable "description"            { type = string }
variable "log_retention_days"     { type = number }

# ENV & Tags
variable "env"  { type = map(string) }
variable "tags" { type = map(string) }

# Rolle
variable "role_name_suffix" { type = string }            # z.B. "Lambda2-role"
variable "role_path"        { type = string, default = "/service-role/" }

# VPC (optional)
variable "attach_vpc_access"  { type = bool }
variable "subnet_ids"         { type = list(string) }
variable "security_group_ids" { type = list(string) }

# Bedrock (Inline-Policy nur auf dieses Modell)
variable "bedrock_model_id" { type = string }            # z.B. "amazon.titan-embed-text-v2:0"

############################
# Validations
############################
# Entweder use_archive=true ODER filename muss gesetzt sein
validation {
  condition     = var.use_archive || (length(var.filename) > 0)
  error_message = "Entweder 'use_archive=true' ODER 'filename' (fertiges ZIP) muss gesetzt sein."
}
# Wenn Archivierung genutzt wird, muss source_file gesetzt sein
validation {
  condition     = !var.use_archive || (length(var.source_file) > 0)
  error_message = "Wenn 'use_archive=true', muss 'source_file' auf die Quell-Datei zeigen."
}
# Bedrock Modell-ID darf nicht leer sein
validation {
  condition     = length(var.bedrock_model_id) > 0
  error_message = "bedrock_model_id darf nicht leer sein."
}

############################
# Umgebung
############################
data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

locals {
  role_name         = var.role_name_suffix
  bedrock_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}"
}

############################
# IAM: Trust + Role + Policies
############################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["lambda.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role" {
  name               = local.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

# CloudWatch Logs (AWS managed)
resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC ENI (nur wenn benötigt)
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count      = var.attach_vpc_access ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Bedrock: InvokeModel NUR für das angegebene Modell
resource "aws_iam_role_policy" "bedrock_invoke" {
  name = "BedrockInvokeModel"
  role = aws_iam_role.role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid      = "AllowInvokeModelStrict",
      Effect   = "Allow",
      Action   = ["bedrock:InvokeModel"],
      Resource = local.bedrock_model_arn
    }]
  })
}

############################
# CloudWatch LogGroup
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

  dynamic "vpc_config" {
    for_each = var.attach_vpc_access && length(var.subnet_ids) > 0 && length(var.security_group_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  environment { variables = var.env }

  depends_on = concat(
    [aws_cloudwatch_log_group.lg, aws_iam_role_policy_attachment.basic_exec, aws_iam_role_policy.bedrock_invoke],
    var.attach_vpc_access ? [aws_iam_role_policy_attachment.vpc_access] : []
  )

  tags = var.tags
}

############################
# Outputs
############################
output "lambda_function_arn" { value = aws_lambda_function.fn.arn }
output "lambda_role_arn"     { value = aws_iam_role.role.arn }
