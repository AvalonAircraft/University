data "aws_caller_identity" "current" {}
data "aws_partition"       "current" {}
data "aws_region"          "current" {}

variable "region"                { type = string, default = "us-east-1" }
variable "role_name"             { type = string, default = "Lambda2-role-5gqtj7be" }

# Bedrock Foundation Model (Titan Embed in gleicher Region)
variable "bedrock_model_arn" {
  type    = string
  default = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
}

# Optional Streaming-Permission (für Chat/Gen-Modelle sinnvoll; Titan-Embed benötigt es i. d. R. nicht)
variable "allow_streaming"       { type = bool,   default = false }

# Kundenverwaltete vs. AWS-Managed Policies umschalten
variable "use_customer_managed"  { type = bool,   default = true }

variable "tags" {
  type = map(string)
  default = {
    Projekt         = "MiraeDrive"
    "StartUp-Modus" = "true"
    Umgebung        = "Produktiv"
    TenantID = ""
  }
}
