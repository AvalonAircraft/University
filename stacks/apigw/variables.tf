variable "region" {
  type    = string
  default = "us-east-1"
}

variable "api_name" {
  type    = string
  default = "GeneralGateway"
}

variable "api_description" {
  type    = string
  default = "REST (EDGE) with Lambda + S3 integrations"
}

# Portable: Names instead of ARNs
variable "lambda_aurora_function_name" {
  type        = string
  description = "Lambda function name for the /aurora-db integration"
}

variable "lambda_agent_function_name" {
  type        = string
  description = "Lambda function name for the /lambda-agent_handler integration"
}

variable "s3_bucket_name" {
  type        = string
  description = "S3 bucket used by /s3-storage/{proxy+} integration"
}
