variable "region" {
  description = "AWS-Region (z.B. us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "alias_name" {
  description = "Alias ohne 'alias/', z.B. 'ecr-key'"
  type        = string
  default     = "ecr-key"
}

variable "description" {
  description = "Beschreibung des Keys"
  type        = string
  default     = "KMS key for ECR repository encryption/decryption"
}

variable "enable_multi_region" {
  description = "Multi-Region-Key?"
  type        = bool
  default     = false
}

variable "repository_arn" {
  description = "ECR-Repository ARN, z.B. arn:aws:ecr:us-east-1:<acct>:repository/tenant1/hr-agent"
  type        = string
}

variable "tags" {
  description = "Zusätzliche Tags"
  type        = map(string)
  default = {
    Project     = "University"
    Environment = "Dev"
    Component   = "ecr-key"
    TenantID    = ""
  }
}
