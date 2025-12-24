data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

############################
# Inputs
############################
variable "role_name"   { type = string }
variable "role_path"   { type = string,  default = "/service-role/" }
variable "policy_arns" { type = list(string), default = [] }
variable "bucket_name" { type = string } # z.B. "miraedrive-assets"
variable "tags"        { type = map(string),   default = {} }

# Guard
variable "role_name" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "combined_check" {
  type = string
  default = "" # Dummy, nur damit der Block existiert

  validation {
    condition     = length(var.role_name) > 0 && length(var.bucket_name) > 0
    error_message = "role_name und bucket_name dürfen nicht leer sein."
  }
}


############################
# Trust policy (Lambda)
############################
data "aws_iam_policy_document" "trust_lambda" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["lambda.amazonaws.com"] }
    actions    = ["sts:AssumeRole"]
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
# Attach managed policies (customer- oder aws-managed)
############################
resource "aws_iam_role_policy_attachment" "attached" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

############################
# Inline policy: S3 (Put/Get/Tagging auf Bucket/*)
############################
data "aws_iam_policy_document" "s3_inline" {
  statement {
    sid     = "PutPDFsToTenantFolder"
    effect  = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:GetObject"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "s3_inline" {
  name   = "s3"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.s3_inline.json
}

############################
# Outputs
############################
output "role_name" { value = aws_iam_role.this.name }
output "role_arn"  { value = aws_iam_role.this.arn  }
