# stacks/apigw/variables.tf
variable "region"          { type = string, default = "us-east-1" }
variable "api_name"        { type = string, default = "GeneralGateway" }
variable "api_description" { type = string, default = "REST (EDGE) with Lambda + S3 integrations" }

variable "lambda_arn_aurora" { type = string }
variable "lambda_arn_agent"  { type = string }
variable "s3_bucket_name"    { type = string }
