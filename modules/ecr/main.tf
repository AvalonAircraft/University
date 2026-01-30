# modules/ecr/main.tf

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}


# Inputs


variable "repository_name" {
  description = "z.B. 'tenant1/hr-agent'"
  type        = string
}

variable "kms_key_arn" {
  description = "arn:aws:kms:..."
  type        = string
}

variable "scan_on_push" {
  description = "Scan on push enabled? (Manuell in Console => false)"
  type        = bool
  default     = false
}

variable "image_tag_mutability" {
  description = "IMMUTABLE or MUTABLE"
  type        = string
  default     = "IMMUTABLE"
}

variable "lifecycle_policy_json" {
  description = "Optional JSON string for lifecycle policy. Leer => keine Policy."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags map"
  type        = map(string)
  default     = {}
}


# ECR Repository


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


# (Optional) Lifecycle Policy


resource "aws_ecr_lifecycle_policy" "this" {
  count = var.lifecycle_policy_json == "" ? 0 : 1

  repository = aws_ecr_repository.this.name
  policy     = var.lifecycle_policy_json
}


# Outputs


output "repository_name" {
  value = aws_ecr_repository.this.name
}

output "repository_arn" {
  value = aws_ecr_repository.this.arn
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}
