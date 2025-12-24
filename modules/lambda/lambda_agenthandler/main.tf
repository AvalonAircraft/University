############################
# Variablen (Module)
############################
variable "function_name" { type = string }
variable "runtime"       { type = string, default = "python3.12" }     # z.B. "python3.12"
variable "handler"       { type = string, default = "lambda_function.lambda_handler" }

# Code-Quelle: EINE Variante
variable "use_archive" { type = bool,   default = false }  # true => packe source_file automatisch
variable "source_file" { type = string, default = "" }     # z.B. ./src/lambda_function.py
variable "filename"    { type = string, default = "" }     # fertiges ZIP

variable "memory_size"            { type = number, default = 128 }
variable "ephemeral_storage_size" { type = number, default = 512 }
variable "timeout"                { type = number, default = 3 }
variable "env"                    { type = map(string), default = {} }
variable "tags"                   { type = map(string), default = {} }

# VPC (optional)
variable "subnet_ids"         { type = list(string), default = [] }
variable "security_group_ids" { type = list(string), default = [] }
variable "attach_vpc_access"  { type = bool, default = false } # nur anhängen, wenn true

# Policies: standard AWS-managed; bei Kunden-Policies hier eigene ARNs setzen
data "aws_partition" "current" {}
data "aws_region"    "current" {}

variable "policy_arn_basic_exec" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
variable "policy_arn_vpc_access" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# STRIKT: EventBridge-Bus (Name, nicht ARN) – bei leerem String wird keine EB-Policy erzeugt
variable "event_bus_name" { type = string, default = "" }

# Rollen-Namen/-Pfad
variable "role_name_suffix" { type = string, default = "" }            # leer => aus function_name
variable "role_path"        { type = string, default = "/service-role/" }

############################
# Umgebung (Account/Region/Partition)
############################
data "aws_caller_identity" "current" {}
# data "aws_region" / "aws_partition" bereits oben

locals {
  role_name = var.role_name_suffix != "" ? var.role_name_suffix : "${var.function_name}-role"

  # EventBus ARN strikt auf aktuellen Account/Region/Partition
  event_bus_arn = var.event_bus_name == "" ? null :
    "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/${var.event_bus_name}"
}

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
# IAM: Trust + Role
############################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["lambda.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = local.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

# Logs (AWS managed ODER kundenspezifisch via Variable)
resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.this.name
  policy_arn = var.policy_arn_basic_exec
}

# VPC ENI (nur wenn attach_vpc_access = true)
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count      = var.attach_vpc_access ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = var.policy_arn_vpc_access
}

# EventBridge PutEvents – STRIKT auf den angegebenen Bus
resource "aws_iam_role_policy" "eventbridge_put_strict" {
  count = local.event_bus_arn == null ? 0 : 1
  name  = "${var.function_name}-eventbridge-put"
  role  = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["events:PutEvents"],
      Resource = local.event_bus_arn
    }]
  })
}

############################
# Log Group (Retention)
############################
resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

############################
# Code-Paket
############################
# Variante A: automatisch packen aus einer Datei
data "archive_file" "pkg" {
  count       = var.use_archive ? 1 : 0
  type        = "zip"
  source_file = var.source_file
  output_path = "${path.module}/.build/${var.function_name}.zip"
}

locals {
  code_filename = var.use_archive ? data.archive_file.pkg[0].output_path : var.filename
  code_hash     = var.use_archive ? data.archive_file.pkg[0].output_base64sha256 : filebase64sha256(var.filename)
}

############################
# Lambda-Funktion
############################
resource "aws_lambda_function" "fn" {
  function_name    = var.function_name
  role             = aws_iam_role.this.arn
  runtime          = var.runtime
  handler          = var.handler

  filename         = local.code_filename
  source_code_hash = local.code_hash

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
    [aws_cloudwatch_log_group.lg, aws_iam_role_policy_attachment.basic_exec],
    var.attach_vpc_access ? [aws_iam_role_policy_attachment.vpc_access] : [],
    local.event_bus_arn == null ? [] : [aws_iam_role_policy.eventbridge_put_strict]
  )

  tags = var.tags
}

############################
# Outputs
############################
output "lambda_function_arn" { value = aws_lambda_function.fn.arn }
output "lambda_role_arn"     { value = aws_iam_role.this.arn }
