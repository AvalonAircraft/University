############################
# Lookups (VPC, Subnets, SGs, NLB)
############################

# VPC per Name-Tag
data "aws_vpc" "target" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Private Subnets per Name-Tag
data "aws_subnet" "private1" {
  filter {
    name   = "tag:Name"
    values = [var.subnet_private1_name]
  }
  vpc_id = data.aws_vpc.target.id
}

data "aws_subnet" "private2" {
  filter {
    name   = "tag:Name"
    values = [var.subnet_private2_name]
  }
  vpc_id = data.aws_vpc.target.id
}

# Security Groups per Name
data "aws_security_group" "lambda_ctrl" {
  name   = var.sg_lambda_ctrl_name
  vpc_id = data.aws_vpc.target.id
}

data "aws_security_group" "lambda_vpce" {
  name   = var.sg_lambda_vpce_name
  vpc_id = data.aws_vpc.target.id
}

# NLB per Name (für DEFAULT_NLB_HOSTS)
data "aws_lb" "nlb" {
  name = var.nlb_name
}

############################
# Abgeleitete ENV-Variablen
############################
locals {
  # Falls NLB_PORT nicht im env vorhanden ist, fallback "8080"
  nlb_port          = try(var.env["NLB_PORT"], "8080")
  default_nlb_hosts = "${data.aws_lb.nlb.dns_name}:${local.nlb_port}"

  # finale ENV: meine env + dynamischer DEFAULT_NLB_HOSTS
  env_final = merge(
    var.env,
    { DEFAULT_NLB_HOSTS = local.default_nlb_hosts }
  )
}

############################
# Modul-Aufruf
############################
module "lambda_AgentControlHandler" {
  source = "../../modules/lambda_AgentControlHandler"

  # Lambda-Basics
  function_name = var.function_name
  runtime       = var.runtime
  handler       = var.handler

  # Code
  use_archive = var.use_archive
  source_file = var.source_file
  filename    = var.filename

  # Limits
  memory_size            = var.memory_size
  ephemeral_storage_size = var.ephemeral_storage_size
  timeout                = var.timeout

  # Env & Tags (mit dynamischem DEFAULT_NLB_HOSTS)
  env  = local.env_final
  tags = var.tags

  # VPC (IDs aus Lookups)
  subnet_ids         = [data.aws_subnet.private1.id, data.aws_subnet.private2.id]
  security_group_ids = [data.aws_security_group.lambda_vpce.id, data.aws_security_group.lambda_ctrl.id]
  attach_vpc_access  = var.attach_vpc_access

  # Capabilities / Rechte
  kms_key_alias        = var.kms_key_alias
  s3_read_bucket_names = var.s3_read_bucket_names
  add_elbv2_describe   = var.add_elbv2_describe

  # Role
  role_name_suffix = var.role_name_suffix
}

############################
# Outputs
############################
output "lambda_function_arn" { value = module.lambda_AgentControlHandler.lambda_function_arn }
output "lambda_role_arn"     { value = module.lambda_AgentControlHandler.lambda_role_arn }

# Optionale Debug-Outputs
output "resolved_subnet_ids" {
  value = [data.aws_subnet.private1.id, data.aws_subnet.private2.id]
}
output "resolved_security_group_ids" {
  value = [data.aws_security_group.lambda_vpce.id, data.aws_security_group.lambda_ctrl.id]
}
output "resolved_default_nlb_hosts" {
  value = local.default_nlb_hosts
}
