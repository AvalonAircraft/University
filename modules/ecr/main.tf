data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

############################
# Inputs
############################
variable "repository_name"       { type = string }                          # z.B. "tenant1/hr-agent"
variable "kms_key_arn"           { type = string }                          # arn:${data.aws_partition.current.partition}:kms:... (MRK ok)
variable "scan_on_push"          { type = bool,   default = false }         # "Manuell" in deiner Konsole => false
variable "image_tag_mutability"  { type = string, default = "IMMUTABLE" }   # "IMMUTABLE" oder "MUTABLE"
variable "lifecycle_policy_json" { type = string, default = "" }            # optional, leer => keine Policy
variable "tags"                  { type = map(string), default = {} }

############################
# ECR Repository
############################
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = var.tags
}

############################
# (Optional) Lifecycle Policy
############################
resource "aws_ecr_lifecycle_policy" "this" {
  count      = var.lifecycle_policy_json == "" ? 0 : 1
  repository = aws_ecr_repository.this.name
  policy     = var.lifecycle_policy_json
}

############################
# Outputs
############################
output "repository_name" { value = aws_ecr_repository.this.name }
output "repository_arn"  { value = aws_ecr_repository.this.arn }
output "repository_url"  { value = aws_ecr_repository.this.repository_url }
