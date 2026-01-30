# Module: NLB-Fargate-PrivateLink


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# --- Data ---
data "aws_region"    "current" {}
data "aws_partition" "current" {}


# Variables


variable "name"              { type = string }
variable "vpc_id"            { type = string }
variable "subnet_ids"        { type = list(string) }
variable "security_group_id" { type = string }
variable "internal"          { type = bool,   default = true }
variable "ip_address_type"   { type = string, default = "dualstack" }
variable "tags"              { type = map(string), default = {} }

# Target Group
variable "tg_name"        { type = string, default = "fargate-nlb-targets" }
variable "tg_protocol"    { type = string, default = "TCP" }
variable "tg_port"        { type = number, default = 8080 }
variable "tg_target_type" { type = string, default = "ip" }

# Listener
variable "listener_protocol" { type = string, default = "TCP" }
variable "listener_port"     { type = number, default = 8080 }

# Health Check
variable "hc_enabled"       { type = bool,   default = true }
variable "hc_protocol"      { type = string, default = "TCP" }
variable "hc_port"          { type = string, default = "traffic-port" }
variable "hc_interval"      { type = number, default = 10 }
variable "hc_healthy_thr"   { type = number, default = 3 }
variable "hc_unhealthy_thr" { type = number, default = 3 }

# Performance & Safety
variable "enable_cross_zone"   { type = bool, default = true }
variable "deletion_protection" { type = bool, default = false }


# Resources


# 1. Der Network Load Balancer
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "network"
  internal           = var.internal
  ip_address_type    = var.ip_address_type
  subnets            = var.subnet_ids
  
  # Hinweis: Security Groups werden beim NLB über die Attachment-Ressource verwaltet,
  # um Konflikte bei Updates zu vermeiden.
  security_groups    = [] 

  enable_cross_zone_load_balancing = var.enable_cross_zone
  deletion_protection_enabled      = var.deletion_protection

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = contains(["ipv4", "dualstack"], var.ip_address_type)
      error_message = "Der ip_address_type muss 'ipv4' oder 'dualstack' sein."
    }
    precondition {
      condition     = length(var.subnet_ids) >= 2
      error_message = "Für Hochverfügbarkeit müssen mindestens 2 Subnetze angegeben werden."
    }
  }
}

# 2. Security Group Attachment (Modernes NLB Feature)
resource "aws_lb_security_group_attachment" "nlb_sg" {
  load_balancer_arn = aws_lb.this.arn
  security_group_id = var.security_group_id
}

# 3. Target Group (Target-Type 'ip' ist Pflicht für Fargate)
resource "aws_lb_target_group" "this" {
  name        = var.tg_name
  vpc_id      = var.vpc_id
  port        = var.tg_port
  protocol    = var.tg_protocol
  target_type = var.tg_target_type

  health_check {
    enabled             = var.hc_enabled
    protocol            = var.hc_protocol
    port                = var.hc_port
    interval            = var.hc_interval
    healthy_threshold   = var.hc_healthy_thr
    unhealthy_threshold = var.hc_unhealthy_thr
  }

  tags = merge(var.tags, { Name = var.tg_name })

  lifecycle {
    create_before_destroy = true
  }
}

# 4. Listener
resource "aws_lb_listener" "tcp" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}


# Outputs


output "nlb_arn"         { value = aws_lb.this.arn }
output "nlb_dns_name"    { value = aws_lb.this.dns_name }
output "nlb_zone_id"     { value = aws_lb.this.zone_id }
output "target_group_arn" { value = aws_lb_target_group.this.arn }
