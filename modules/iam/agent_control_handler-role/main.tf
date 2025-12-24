############################
# Data
############################
data "aws_partition"       "current" {}
data "aws_region"          "current" {}
data "aws_caller_identity" "current" {}

############################
# Inputs (mit deinen Defaults)
############################
variable "role_name" {
  type    = string
  default = "AgentControlHandler-role-437qbom8"
  validation {
    condition     = length(var.role_name) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "role_path" {
  type    = string
  default = "/service-role/"
}

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "IAM"
  }
}

# Ressourcen
variable "s3_bucket_name" {
  type    = string
  default = "miraedrive-assets"
  validation {
    condition     = length(var.s3_bucket_name) > 0
    error_message = "s3_bucket_name darf nicht leer sein."
  }
}

variable "kms_key_arn" {
  type    = string
  default = "arn:aws:kms:us-east-1:186261963982:key/mrk-3e9cc314f44947ffb7abb50e39434caa"
  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "kms_key_arn darf nicht leer sein."
  }
}

# Kundenverwaltete Basic-Logs-Policy NAME (wird zu einem ARN zusammengesetzt)
# z.B. "AWSLambdaBasicExecutionRole-terraform"
variable "managed_policy_name" {
  type    = string
  default = "AWSLambdaBasicExecutionRole-39f2dbfa-2382-41b5-9b24-7df95e71254a"
  validation {
    condition     = length(var.managed_policy_name) > 0
    error_message = "managed_policy_name darf nicht leer sein."
  }
}

############################
# Locals
############################
locals {
  # Kundenverwaltete Policy-ARN im aktuellen Account aus dem Namen bauen
  basic_logs_policy_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/${var.managed_policy_name}"
}

############################
# Trust Policy (Lambda)
############################
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

############################
# Role
############################
resource "aws_iam_role" "this" {
  name                  = var.role_name
  path                  = var.role_path
  assume_role_policy    = data.aws_iam_policy_document.assume_lambda.json
  max_session_duration  = 3600
  tags                  = var.tags
}

############################
# Managed Policy (kundenverwaltet; Basic Logs etc.)
############################
resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.this.name
  policy_arn = local.basic_logs_policy_arn
}

############################
# Inline Policy: ENI/ELB (Lambda in VPC + NLB/TG Discover)
############################
data "aws_iam_policy_document" "eni_access" {
  statement {
    sid     = "VpcEniAccess"
    effect  = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateTags",
      "ec2:DeleteNetworkInterface",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "eni_access" {
  name   = "Lambda_VPC_ENI_Access"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.eni_access.json
}

############################
# Inline Policy: Logs + S3 + KMS (entspricht deiner JSON)
############################
data "aws_iam_policy_document" "s3_kms" {
  # CloudWatch Logs (wie in der eigenen S3-Policy JSON enthalten)
  statement {
    sid     = "LambdaBasicLogs"
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ReadEmailFromS3"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}/*"
    ]
  }

  statement {
    sid     = "KmsDecryptForS3"
    effect  = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "s3_kms" {
  name   = "S3"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.s3_kms.json
}

############################
# Outputs
############################
output "role_name" {
  value = aws_iam_role.this.name
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
