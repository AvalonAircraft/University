# modules/apigw_rest/main.tf
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

variable "api_name"        { type = string }
variable "api_description" { type = string, default = "" }

variable "lambda_arn_aurora" { type = string }
variable "lambda_arn_agent"  { type = string }
variable "s3_bucket_name"    { type = string }

# ===== API (EDGE) =====
resource "aws_api_gateway_rest_api" "api" {
  name        = var.api_name
  description = var.api_description
  endpoint_configuration { types = ["EDGE"] }
}

# ===== Ressourcen =====
resource "aws_api_gateway_resource" "aurora_db" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "aurora-db"
}
resource "aws_api_gateway_resource" "lambda_agent" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "lambda-agent_handler"
}
resource "aws_api_gateway_resource" "s3_storage" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "s3-storage"
}
resource "aws_api_gateway_resource" "s3_proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.s3_storage.id
  path_part   = "{proxy+}"
}

# ===== Helper =====
locals {
  lambda_methods = ["GET","POST","PUT","DELETE"]
  s3_methods     = ["GET","PUT","DELETE"]

  lambda_integration_uri = "arn:${data.aws_partition.current.partition}:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/%s/invocations"
  s3_path_base           = "arn:${data.aws_partition.current.partition}:apigateway:${data.aws_region.current.name}:s3:path"
}

data "aws_caller_identity" "me" {}
data "aws_region"          "current_alias" {}

# ===== IAM Rolle für S3-Integration =====
data "aws_iam_policy_document" "apigw_assume" {
  statement {
    effect = "Allow"
    principals { type = "Service", identifiers = ["apigateway.amazonaws.com"] }
    actions   = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "apigw_s3_role" {
  name               = "apigw-s3-integration-role"
  assume_role_policy = data.aws_iam_policy_document.apigw_assume.json
}
data "aws_iam_policy_document" "apigw_s3_policy" {
  statement {
    sid      = "AllowS3RW"
    effect   = "Allow"
    actions  = ["s3:GetObject","s3:PutObject","s3:DeleteObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket_name}/*"]
  }
}
resource "aws_iam_role_policy" "apigw_s3_inline" {
  name   = "apigw-s3-rw"
  role   = aws_iam_role.apigw_s3_role.id
  policy = data.aws_iam_policy_document.apigw_s3_policy.json
}

# ===== /aurora-db → Lambda (Proxy) =====
resource "aws_api_gateway_method" "aurora_methods" {
  for_each      = toset(local.lambda_methods)
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.aurora_db.id
  http_method   = each.key
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "aurora_lambda" {
  for_each                = aws_api_gateway_method.aurora_methods
  rest_api_id             = each.value.rest_api_id
  resource_id             = each.value.resource_id
  http_method             = each.value.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = format(local.lambda_integration_uri, var.lambda_arn_aurora)
}

# ===== /lambda-agent_handler → Lambda (Proxy) =====
resource "aws_api_gateway_method" "agent_methods" {
  for_each      = toset(local.lambda_methods)
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.lambda_agent.id
  http_method   = each.key
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "agent_lambda" {
  for_each                = aws_api_gateway_method.agent_methods
  rest_api_id             = each.value.rest_api_id
  resource_id             = each.value.resource_id
  http_method             = each.value.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = format(local.lambda_integration_uri, var.lambda_arn_agent)
}

# ===== /s3-storage/{proxy+} → S3 Service =====
resource "aws_api_gateway_method" "s3_proxy_methods" {
  for_each      = toset(local.s3_methods)
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.s3_proxy.id
  http_method   = each.key
  authorization = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}
resource "aws_api_gateway_integration" "s3_proxy_integration" {
  for_each                 = aws_api_gateway_method.s3_proxy_methods
  rest_api_id              = each.value.rest_api_id
  resource_id              = each.value.resource_id
  http_method              = each.value.http_method
  type                     = "AWS"
  credentials              = aws_iam_role.apigw_s3_role.arn
  integration_http_method  = each.value.http_method
  uri                      = "${local.s3_path_base}/${var.s3_bucket_name}/{proxy}"
  request_parameters       = { "integration.request.path.proxy" = "method.request.path.proxy" }
  passthrough_behavior     = "WHEN_NO_MATCH"
}

# ===== Responses (minimal) =====
resource "aws_api_gateway_method_response" "all_200" {
  for_each    = {
    for k, v in merge(
      aws_api_gateway_method.aurora_methods,
      aws_api_gateway_method.agent_methods,
      aws_api_gateway_method.s3_proxy_methods
    ) : k => v
  }
  rest_api_id = each.value.rest_api_id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"
}
resource "aws_api_gateway_integration_response" "all_iresp_200" {
  for_each    = {
    for k, v in merge(
      aws_api_gateway_integration.aurora_lambda,
      aws_api_gateway_integration.agent_lambda,
      aws_api_gateway_integration.s3_proxy_integration
    ) : k => v
  }
  rest_api_id = each.value.rest_api_id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"
  depends_on  = [aws_api_gateway_integration.s3_proxy_integration, aws_api_gateway_integration.aurora_lambda, aws_api_gateway_integration.agent_lambda]
}

# ===== Deployment + Stage =====
resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeploy_hash = sha1(join(",", [
      for k, m in aws_api_gateway_method.aurora_methods : "${k}-${m.http_method}"
    ]))
  }
  lifecycle { create_before_destroy = true }
  depends_on = [
    aws_api_gateway_integration.aurora_lambda,
    aws_api_gateway_integration.agent_lambda,
    aws_api_gateway_integration.s3_proxy_integration,
    aws_api_gateway_method_response.all_200,
    aws_api_gateway_integration_response.all_iresp_200
  ]
}
resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deploy.id
  stage_name    = "prod"
}

# ===== Lambda Invoke Permissions =====
resource "aws_lambda_permission" "allow_apigw_aurora" {
  statement_id  = "AllowAPIGWInvokeAurora"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arn_aurora
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:${data.aws_partition.current.partition}:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.me.account_id}:${aws_api_gateway_rest_api.api.id}/*/*/aurora-db"
}
resource "aws_lambda_permission" "allow_apigw_agent" {
  statement_id  = "AllowAPIGWInvokeAgent"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arn_agent
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:${data.aws_partition.current.partition}:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.me.account_id}:${aws_api_gateway_rest_api.api.id}/*/*/lambda-agent_handler"
}

# ===== Outputs =====
output "api_id"     { value = aws_api_gateway_rest_api.api.id }
output "invoke_url" { value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}" }
