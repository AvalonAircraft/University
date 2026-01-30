variable "region" {
  type    = string
  default = "us-east-1"
}

# Role Path (portable / optional anpassbar)
variable "role_path" {
  type        = string
  description = "IAM role path"
  default     = "/"
}

# Rolle (Name kann kollidieren; wenn Professor mehrfach deployt, besser unique machen)
variable "role_name" {
  type        = string
  description = "IAM role name for ECS task execution role"
  default     = "ecsTaskExecutionRole-ai-agent"
}

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    Type            = "IAM"
    TenantID        = ""
  }
}

# optional: weitere Managed Policies anhängen (i. d. R. leer lassen)
variable "extra_policy_arns" {
  type        = list(string)
  description = "Optional additional managed policy ARNs to attach"
  default     = []
}
