############################
# Inputs
############################
variable "vpc_id"        { type = string }
variable "private1_cidr" { type = string } # 10.0.128.0/20
variable "private2_cidr" { type = string } # 10.0.144.0/20
variable "tags"          { type = map(string), default = {} }

# Konfigurierbare AWS-CIDRs für Lambda VPCE Ingress (Option B)
variable "lambda_vpce_ingress_cidrs" {
  type = list(string)
  default = [
    "3.218.0.0/15", "18.204.0.0/14", "52.90.0.0/15",
    "54.152.0.0/16", "54.160.0.0/16", "54.172.0.0/15", "54.174.0.0/15",
    "54.196.0.0/15", "54.198.0.0/16", "54.204.0.0/15", "54.208.0.0/15",
    "54.236.0.0/15", "54.242.0.0/15", "54.210.0.0/15"
  ]
}

# Optional: IPv6 Ingress für NLB/ECS (z.B. wenn man IPv6 intern nutzt)
variable "enable_ipv6_ingress" { type = bool, default = false }

locals {
  tags = var.tags
}

############################
# Security Groups (leer, Regeln separat)
############################
resource "aws_security_group" "aurora" {
  name        = "AuroraDB"
  description = "AuroraDB SG"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "AuroraDB" })
}

resource "aws_security_group" "ecr_api" {
  name        = "ECR API SG"
  description = "ECR API SG (VPC Endpoint)"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "ECR API SG" })
}

resource "aws_security_group" "ecs_fargate" {
  name        = "ecs-fargate"
  description = "ECS/Fargate + PrivateLink comms"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "ecs-fargate" })
}

resource "aws_security_group" "lambda_agent_control" {
  name        = "Lambda_AgentControlHandler"
  description = "Lambda SG for AgentControlHandler"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "Lambda_AgentControlHandler" })
}

resource "aws_security_group" "lambda6_to_vpce" {
  name        = "lambda_6_to_vpc_endpoint"
  description = "Lambda6 to AuroraDB & VPCE"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "lambda_6_to_vpc_endpoint" })
}

resource "aws_security_group" "secretsmanager_ep" {
  name        = "secret_manager_endpoint_sg"
  description = "Secrets Manager VPCE SG"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "secret_manager_endpoint_sg" })
}

resource "aws_security_group" "nlb_fargate_privatelink" {
  name        = "nlb-fargate-privatelink"
  description = "NLB to AI agents (Fargate) with PrivateLink"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "nlb-fargate-privatelink" })
}

# Lambda VPC Endpoint SG
resource "aws_security_group" "lambda_vpc_endpoint" {
  name        = "lambda-vpc-endpoint"
  description = "Security Group for Lambda VPC Endpoint with HTTPS access"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "lambda-vpc-endpoint" })
}

############################
# Default / Egress
############################
resource "aws_vpc_security_group_egress_rule" "ecs_fargate_all" {
  security_group_id = aws_security_group.ecs_fargate.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all egress"
}

# lambda_6_to_vpce: egress 443 0.0.0.0/0 + egress 3306 -> Aurora SG
resource "aws_vpc_security_group_egress_rule" "lambda6_https_out" {
  security_group_id = aws_security_group.lambda6_to_vpce.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTPS to anywhere (VPCEs, etc.)"
}
resource "aws_vpc_security_group_egress_rule" "lambda6_to_aurora" {
  security_group_id            = aws_security_group.lambda6_to_vpce.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.aurora.id
  description                  = "MySQL/Aurora to AuroraDB SG"
}

# secret_manager_endpoint_sg: egress all
resource "aws_vpc_security_group_egress_rule" "secrets_ep_all" {
  security_group_id = aws_security_group.secretsmanager_ep.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all egress"
}

# nlb-fargate-privatelink: egress 443 & 8080 to ecs-fargate
resource "aws_vpc_security_group_egress_rule" "nlb_to_fargate_https" {
  security_group_id            = aws_security_group.nlb_fargate_privatelink.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.ecs_fargate.id
  description                  = "HTTPS to ECS/Fargate"
}
resource "aws_vpc_security_group_egress_rule" "nlb_to_fargate_8080" {
  security_group_id            = aws_security_group.nlb_fargate_privatelink.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.ecs_fargate.id
  description                  = "TCP/8080 to ECS/Fargate"
}

# lambda-vpc-endpoint -> egress 443 to nlb-fargate-privatelink
resource "aws_vpc_security_group_egress_rule" "lambda_vpce_to_nlb_https" {
  security_group_id            = aws_security_group.lambda_vpc_endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.nlb_fargate_privatelink.id
  description                  = "HTTPS to NLB/Fargate"
}

############################
# Ingress
############################
# AuroraDB: ingress 3306 from lambda_6_to_vpce
resource "aws_vpc_security_group_ingress_rule" "aurora_from_lambda6" {
  security_group_id            = aws_security_group.aurora.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.lambda6_to_vpce.id
  description                  = "MySQL/Aurora from lambda_6_to_vpc_endpoint"
}

# (optional) AuroraDB: egress 3306 to lambda_6_to_vpce (nur nötig für rückkanal-initiierte Verbindungen)
resource "aws_vpc_security_group_egress_rule" "aurora_to_lambda6" {
  security_group_id            = aws_security_group.aurora.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.lambda6_to_vpce.id
  description                  = "MySQL/Aurora to lambda_6_to_vpc_endpoint"
}

# ECR API SG: ingress 443 from ecs-fargate
resource "aws_vpc_security_group_ingress_rule" "ecr_api_from_fargate" {
  security_group_id            = aws_security_group.ecr_api.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.ecs_fargate.id
  description                  = "HTTPS from ecs-fargate"
}

# ecs-fargate:
# - ingress 443 from itself (SG self)
resource "aws_vpc_security_group_ingress_rule" "fargate_self_https" {
  security_group_id            = aws_security_group.ecs_fargate.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.ecs_fargate.id
  description                  = "HTTPS from self"
}
# - ingress 8080 from private1/2 CIDR
resource "aws_vpc_security_group_ingress_rule" "fargate_8080_priv1" {
  security_group_id = aws_security_group.ecs_fargate.id
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = var.private1_cidr
  description       = "TCP/8080 from private1"
}
resource "aws_vpc_security_group_ingress_rule" "fargate_8080_priv2" {
  security_group_id = aws_security_group.ecs_fargate.id
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = var.private2_cidr
  description       = "TCP/8080 from private2"
}
# - ingress 8080 from Lambda_AgentControlHandler SG
resource "aws_vpc_security_group_ingress_rule" "fargate_8080_from_lambda_ctrl" {
  security_group_id            = aws_security_group.ecs_fargate.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.lambda_agent_control.id
  description                  = "TCP/8080 from Lambda_AgentControlHandler"
}

# Secrets Manager VPCE: ingress 443 from lambda_6_to_vpce
resource "aws_vpc_security_group_ingress_rule" "secrets_ep_from_lambda6" {
  security_group_id            = aws_security_group.secretsmanager_ep.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.lambda6_to_vpce.id
  description                  = "HTTPS from lambda_6_to_vpc_endpoint"
}

# NLB (PrivateLink): ingress 8080 & 443 from Lambda_AgentControlHandler
resource "aws_vpc_security_group_ingress_rule" "nlb_from_lambda_ctrl_8080" {
  security_group_id            = aws_security_group.nlb_fargate_privatelink.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.lambda_agent_control.id
  description                  = "TCP/8080 from Lambda_AgentControlHandler"
}
resource "aws_vpc_security_group_ingress_rule" "nlb_from_lambda_ctrl_https" {
  security_group_id            = aws_security_group.nlb_fargate_privatelink.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.lambda_agent_control.id
  description                  = "HTTPS from Lambda_AgentControlHandler"
}

# Lambda VPC Endpoint – Ingress 443 from AWS IP-Ranges (14)
resource "aws_vpc_security_group_ingress_rule" "lambda_vpce_ingress" {
  for_each          = toset(var.lambda_vpce_ingress_cidrs)
  security_group_id = aws_security_group.lambda_vpc_endpoint.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
  description       = "HTTPS from AWS range ${each.value}"
}

# (Optional) IPv6 für NLB/ECS (intern)
resource "aws_vpc_security_group_ingress_rule" "fargate_ipv6_https_self" {
  count                      = var.enable_ipv6_ingress ? 1 : 0
  security_group_id          = aws_security_group.ecs_fargate.id
  ip_protocol                = "tcp"
  from_port                  = 443
  to_port                    = 443
  referenced_security_group_id = aws_security_group.ecs_fargate.id
  description                = "IPv6 HTTPS from self"
  cidr_ipv6                  = null
}

############################
# Outputs
############################
output "sg_aurora_id"                  { value = aws_security_group.aurora.id }
output "sg_ecr_api_id"                 { value = aws_security_group.ecr_api.id }
output "sg_ecs_fargate_id"             { value = aws_security_group.ecs_fargate.id }
output "sg_lambda_agent_control_id"    { value = aws_security_group.lambda_agent_control.id }
output "sg_lambda6_to_vpce_id"         { value = aws_security_group.lambda6_to_vpce.id }
output "sg_secretsmanager_ep_id"       { value = aws_security_group.secretsmanager_ep.id }
output "sg_nlb_fargate_privatelink_id" { value = aws_security_group.nlb_fargate_privatelink.id }
output "sg_lambda_vpc_endpoint_id"     { value = aws_security_group.lambda_vpc_endpoint.id }
