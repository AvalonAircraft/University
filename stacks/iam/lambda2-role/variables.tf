variable "region" {
  type    = string
  default = "us-east-1"
}

variable "role_name" {
  type    = string
  default = "Lambda2-role-5gqtj7be"
}

variable "role_path" {
  type    = string
  default = "/service-role/"
}

# Bedrock Foundation Model (Titan Embed ist global in ARN ohne Account-ID)
variable "bedrock_model_arn" {
  type    = string
  default = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
}

# Optional Streaming-Permission (für Chat/Gen-Modelle sinnvoll; Titan-Embed braucht es i. d. R. nicht)
variable "allow_streaming" {
  type    = bool
  default = false
}

# PORTABLE DEFAULT: im Professor-Account gibt es deine Customer-Policies nicht
variable "use_customer_managed" {
  type    = bool
  default = false
}

# Nur relevant wenn use_customer_managed = true
variable "customer_basic_logs_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy (Klon von AWSLambdaBasicExecutionRole)"
  default     = "AWSLambdaBasicExecutionRole-2d852cb3-ed3b-43fa-8a18-293eb1794f3d"
}

variable "customer_vpc_access_policy_name" {
  type        = string
  description = "Name der kundenverwalteten Policy (Klon von AWSLambdaVPCAccessExecutionRole)"
  default     = "AWSLambdaVPCAccessExecutionRole-34d15055-e437-426b-9420-0db4540b4a84"
}

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID        = ""
  }
}
