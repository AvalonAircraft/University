# Module: Security-Matrix-Core


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}


# Security Group Ressourcen


# Wir definieren zuerst alle SGs als "Hüllen", um zirkuläre Referenzen 
# in den Regeln (Rules) ohne Probleme auflösen zu können.

resource "aws_security_group" "aurora" {
  name        = "AuroraDB-SG"
  description = "Security Group for Aurora MySQL Cluster"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "aurora-db-sg" })
}

resource "aws_security_group" "ecr_api" {
  name        = "ECR-VPCE-SG"
  description = "Security Group for ECR VPC Endpoints"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "ecr-vpce-sg" })
}

resource "aws_security_group" "ecs_fargate" {
  name        = "ECS-Fargate-SG"
  description = "Security Group for AI Agent Containers"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "ecs-fargate-sg" })
}

resource "aws_security_group" "lambda_agent_control" {
  name        = "Lambda-AgentCtrl-SG"
  description = "Security Group for Agent Control Lambda"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "lambda-agent-ctrl-sg" })
}

resource "aws_security_group" "lambda6_to_vpce" {
  name        = "Lambda6-VPC-SG"
  description = "Security Group for Data Processing Lambda"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "lambda-6-sg" })
}

resource "aws_security_group" "secretsmanager_ep" {
  name        = "SecretsManager-VPCE-SG"
  description = "Security Group for Secrets Manager Endpoint"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "secretsmanager-vpce-sg" })
}

resource "aws_security_group" "nlb_fargate_privatelink" {
  name        = "NLB-PrivateLink-SG"
  description = "Security Group for NLB PrivateLink Endpoint"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "nlb-privatelink-sg" })
}

resource "aws_security_group" "lambda_vpc_endpoint" {
  name        = "Lambda-VPCE-SG"
  description = "Security Group for Lambda VPC Interface Endpoint"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "lambda-vpce-sg" })
}


# Egress Rules (Outbound)


resource "aws_vpc_security_group_egress_rule" "global_egress" {
  for_each = toset([
    aws_security_group.ecs_fargate.id,
    aws_security_group.lambda6_to_vpce.id,
    aws_security_group.secretsmanager_ep.id,
    aws_security_group.lambda_agent_control.id
  ])
  security_group_id = each.value
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic for processing services"
}

resource "aws_vpc_security_group_egress_rule" "lambda_vpce_to_nlb" {
  security_group_id            = aws_security_group.lambda_vpc_endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.nlb_fargate_privatelink.id
  description                  = "HTTPS to NLB Endpoint"
}


# Ingress Rules (Inbound)


# AuroraDB von Lambda 6
resource "aws_vpc_security_group_ingress_rule" "aurora_in" {
  security_group_id            = aws_security_group.aurora.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.lambda6_to_vpce.id
  description                  = "MySQL from Lambda 6"
}

# ECR API von Fargate
resource "aws_vpc_security_group_ingress_rule" "ecr_in" {
  security_group_id            = aws_security_group.ecr_api.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.ecs_fargate.id
  description                  = "ECR Pull from Fargate"
}

# ECS Fargate Rules
resource "aws_vpc_security_group_ingress_rule" "fargate_from_nlb" {
  security_group_id            = aws_security_group.ecs_fargate.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.nlb_fargate_privatelink.id
  description                  = "Traffic from NLB"
}

resource "aws_vpc_security_group_ingress_rule" "fargate_from_lambda_ctrl" {
  security_group_id            = aws_security_group.ecs_fargate.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.lambda_agent_control.id
  description                  = "Control commands from Lambda"
}

# Lambda VPC Endpoint (Ingress via AWS IP-Ranges für Cross-Account/Service Calls)
resource "aws_vpc_security_group_ingress_rule" "lambda_vpce_aws_ranges" {
  for_each          = toset(var.lambda_vpce_ingress_cidrs)
  security_group_id = aws_security_group.lambda_vpc_endpoint.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
  description       = "Inbound HTTPS from AWS Internal Ranges"
}


# Outputs


output "sg_ids" {
  value = {
    aurora         = aws_security_group.aurora.id
    ecr            = aws_security_group.ecr_api.id
    fargate        = aws_security_group.ecs_fargate.id
    lambda_ctrl    = aws_security_group.lambda_agent_control.id
    lambda6        = aws_security_group.lambda6_to_vpce.id
    secrets        = aws_security_group.secretsmanager_ep.id
    nlb            = aws_security_group.nlb_fargate_privatelink.id
    lambda_vpce    = aws_security_group.lambda_vpc_endpoint.id
  }
}
