# Module: lambda-bedrock-processor


data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}


# Inputs


variable "function_name" { type = string }
variable "runtime"       { type = string }
variable "handler"       { type = string }

variable "use_archive" { 
  type        = bool 
  description = "True: Packt source_file in ZIP. False: Nutzt filename."
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
variable "log_retention_days"     { type = number }

variable "env"  { type = map(string) }
variable "tags" { type = map(string) }

variable "role_name_suffix" { type = string }
variable "role_path"        { type = string, default = "/service-role/" }

# VPC (optional)
variable "attach_vpc_access"  { type = bool, default = false }
variable "subnet_ids"         { type = list(string), default = [] }
variable "security_group_ids" { type = list(string), default = [] }

# Bedrock
variable "bedrock_model_id" { 
  type        = string
  description = "Modell-ID, z.B. amazon.titan-embed-text-v2:0"
}


# Validation Check (Workaround für freie Blöcke)


locals {
  # Validiert ZIP-Quelle
  _validate_zip = (var.use_archive || length(var.filename) > 0) ? null : file("ERROR: ZIP-Quelle fehlt")
  # Validiert Quell-Datei
  _validate_src = (!var.use_archive || length(var.source_file) > 0) ? null : file("ERROR: source_file fehlt")
  
  # Bedrock ARN Konstruktion
  bedrock_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}"
}


# IAM: Trust + Role + Policies


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
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  count      = var.attach_vpc_access ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Bedrock: Streng limitiert auf InvokeModel für die spezifische ID
resource "aws_iam_role_policy" "bedrock_invoke" {
  name = "BedrockInvokeModel"
  role = aws_iam_role.role.id
  policy = jsonencode({
    Version = "2012-10-17",
    # Bedrock benötigt oft keine Region im ARN für foundation-models, 
    # wir nutzen jedoch die saubere ARN-Struktur
    Statement = [{
      Sid      = "AllowInvokeModelStrict",
      Effect   = "Allow",
      Action   = ["bedrock:InvokeModel"],
      Resource = local.bedrock_model_arn
    }]
  })
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
  code_source_hash = var.use_archive ? data.archive_file.pkg[0].output_base64sha256 : filebase64
