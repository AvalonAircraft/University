variable "region" {
  type    = string
  default = "us-east-1"
}


# Role

variable "role_name" {
  type        = string
  description = "IAM role name"
  default     = "Lambda-role-7zfomm5t"
}

variable "role_path" {
  type        = string
  description = "IAM role path"
  default     = "/service-role/"
}


# Resources (portable defaults)

variable "bucket_name" {
  type        = string
  description = "S3 bucket name the role should access"
  default     = "miraedrive-assets"
}

# KMS: prefer alias lookup for portability
variable "kms_key_arn" {
  type        = string
  description = "Optional: existing KMS key ARN. Leave empty to use kms_key_alias."
  default     = ""
}

variable "kms_key_alias" {
  type        = string
  description = "Optional: KMS key alias to look up (e.g. alias/kms-tenant-master-key). Used if kms_key_arn is empty."
  default     = "alias/kms-tenant-master-key"
}

# Lambda6: either provide ARN OR function name
variable "lambda6_arn" {
  type        = string
  description = "Optional: Lambda6 function ARN. Leave empty to use lambda6_function_name."
  default     = ""
}

variable "lambda6_function_name" {
  type        = string
  description = "Optional: Lambda6 function name to look up. Used if lambda6_arn is empty."
  default     = "Lambda6_URL-Gen_DB_Saving_SQL-Query"
}

# Step Functions: either provide ARN OR state machine name
variable "stepfn_arn" {
  type        = string
  description = "Optional: Step Functions state machine ARN. Leave empty to use stepfn_state_machine_name."
  default     = ""
}

variable "stepfn_state_machine_name" {
  type        = string
  description = "Optional: Step Functions state machine name to look up. Used if stepfn_arn is empty."
  default     = "StepFunction3_EmailWorkFLow"
}


# Tags

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
