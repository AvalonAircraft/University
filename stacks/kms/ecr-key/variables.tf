variable "region" {
  description = "AWS-Region (z.B. us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "alias_name" {
  description = "Alias ohne 'alias/', z.B. 'ECR_Key'"
  type        = string
  default     = "ECR_Key"
}

variable "description" {
  description = "Beschreibung des Keys"
  type        = string
  default     = "KMS key fuer ECR repository entschluesselung"
}

variable "enable_multi_region" {
  description = "Multi-Region-Key?"
  type        = bool
  default     = true
}

variable "repository_arn" {
  description = "ECR-Repository ARN, z.B. arn:aws:ecr:us-east-1:<acct>:repository/tenant1/hr-agent"
  type        = string
}

variable "tags" {
  description = "Zusätzliche Tags"
  type        = map(string)
  default = {
    Projekt   = "MiraeDrive"
    Umgebung  = "Produktiv"
    Component = "ecr-key"
    TenantID = ""
  }
}
