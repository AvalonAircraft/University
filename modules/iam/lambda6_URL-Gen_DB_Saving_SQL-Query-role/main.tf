data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

############################
# Inputs
############################
variable "role_name"   { type = string }
variable "role_path"   { type = string,  default = "/service-role/" }
variable "policy_arns" { type = list(string), default = [] } # managed policies to attach
variable "tags"        { type = map(string),   default = {} }

# Inline policy inputs (Option A: fertige ARNs; Option B: Cluster-ID + Liste von DB-Usernamen)
variable "kms_key_arn"  { type = string }
variable "s3_bucket"    { type = string }

# Option A (direkt)
variable "rds_db_users" {
  description = "Volle rds-db:connect ARNs. Wenn leer, wird Option B verwendet."
  type        = list(string)
  default     = []
}

# Option B (zusammenbauen)
variable "rds_cluster_resource_id" {
  description = "z.B. cluster-XXXXXXXX… aus der RDS-Konsole (Resource ID, nicht der Hostname). Nur nötig, wenn rds_db_users leer ist."
  type        = string
  default     = ""
}
variable "rds_db_usernames" {
  description = "Liste der DB-Usernamen (z.B. [\"admin_miraedrive\",\"tenant_*_app\"]). Nur nötig, wenn rds_db_users leer ist."
  type        = list(string)
  default     = []
}

############################
# Validations (Editor kann rot färben; Terraform 1.x akzeptiert das)
############################
variable "role_name" {
  type = string

  validation {
    condition     = length(var.role_name) > 0
    error_message = "role_name darf nicht leer sein."
  }
}

variable "s3_bucket" {
  type = string

  validation {
    condition     = length(var.s3_bucket) > 0
    error_message = "s3_bucket darf nicht leer sein."
  }
}

variable "kms_key_arn" {
  type = string

  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "kms_key_arn darf nicht leer sein."
  }
}


############################
# RDS rds-db:connect Ziel-ARNs ermitteln
############################
locals {
  # Wenn rds_db_users explizit übergeben wurden, nutze diese.
  # Sonst konstruiere ARNs aus Region + Account + ClusterResourceId + db_usernames.
  computed_rds_db_users = length(var.rds_db_users) > 0 ? var.rds_db_users : [
    for u in var.rds_db_usernames :
    "arn:${data.aws_partition.current.partition}:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${var.rds_cluster_resource_id}/${u}"
  ]
}

############################
# Trust policy (Lambda)
############################
data "aws_iam_policy_document" "trust_lambda" {
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
# IAM Role
############################
resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = data.aws_iam_policy_document.trust_lambda.json
  tags               = var.tags
}

############################
# Managed policy attachments
############################
resource "aws_iam_role_policy_attachment" "attached" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

############################
# Inline policy "Lambda" (RDS connect + S3 + Logs + KMS)
############################
data "aws_iam_policy_document" "inline_lambda" {
  statement {
    sid      = "RdsDbConnect"
    effect   = "Allow"
    actions  = ["rds-db:connect"]
    resources = local.computed_rds_db_users
  }

  statement {
    sid     = "S3Objects"
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetObject"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket}/*"
    ]
  }

  statement {
    sid     = "S3ListBucket"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket}"
    ]
  }

  statement {
    sid     = "LogsBasic"
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "KmsForS3Objects"
    effect  = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "inline_lambda" {
  name   = "Lambda"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline_lambda.json
}

############################
# Outputs
############################
output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn  }
