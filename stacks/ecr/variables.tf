# Data sources (optional, aber ok)

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}


# Region

variable "region" {
  type        = string
  description = "AWS Region für den Stack (ECR ist regional)."
  default     = "us-east-1"
}


# Repository

variable "repository_name" {
  type        = string
  description = "ECR Repository Name (z.B. \"ai-agent\" oder \"tenant1/hr-agent\")."
  # WICHTIG: Kein author-spezifischer Default, damit fremde Accounts nicht aus Versehen dein Naming übernehmen.
  default     = "ai-agent"
}


# Encryption (KMS optional!)

variable "kms_key_arn" {
  type        = string
  description = "Optional: KMS Key ARN für ECR Encryption. Wenn null/leer, nutzt ECR AWS-managed encryption."
  default     = null
}


# Scanning / Tags / Mutability

variable "scan_on_push" {
  type        = bool
  description = "Wenn true: Scan beim Push; wenn false: manuell."
  default     = false
}

variable "image_tag_mutability" {
  type        = string
  description = "MUTABLE oder IMMUTABLE."
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability muss \"MUTABLE\" oder \"IMMUTABLE\" sein."
  }
}


# Optional Lifecycle Policy (null statt "")

variable "lifecycle_policy_json" {
  type        = string
  description = "Optional: ECR Lifecycle Policy als JSON. Wenn null, wird keine Policy erstellt."
  default     = null
}


# Tags (neutral default)

variable "tags" {
  type        = map(string)
  description = "Tags für Ressourcen."
  default     = {}
}
