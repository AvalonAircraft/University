############################
# Variables
############################
variable "name"              { type = string }                         # z.B. "nlb-fargate"
variable "vpc_id"            { type = string }
variable "subnet_ids"        { type = list(string) }                   # private1 + private2
variable "security_group_id" { type = string }                         # sg-nlb-fargate-privatelink
variable "internal"          { type = bool,   default = true }
variable "ip_address_type"   { type = string, default = "dualstack" }  # "ipv4" | "dualstack"
variable "tags"              { type = map(string), default = {} }

# Target Group
variable "tg_name"        { type = string, default = "fargate-nlb-targets" }
variable "tg_protocol"    { type = string, default = "TCP" }           # TCP/UDP/TLS
variable "tg_port"        { type = number, default = 8080 }
variable "tg_target_type" { type = string, default = "ip" }            # "ip" (für Fargate)

# Listener
variable "listener_protocol" { type = string, default = "TCP" }
variable "listener_port"     { type = number, default = 8080 }

# Health Check
variable "hc_enabled"       { type = bool,   default = true }
variable "hc_protocol"      { type = string, default = "TCP" }         # TCP/HTTP/TLS
variable "hc_port"          { type = string, default = "traffic-port" }
variable "hc_interval"      { type = number, default = 10 }
variable "hc_healthy_thr"   { type = number, default = 3 }
variable "hc_unhealthy_thr" { type = number, default = 3 }

# Optional Hardening/Perf
variable "enable_cross_zone"   { type = bool, default = true }
variable "deletion_protection" { type = bool, default = false }

############################
# Data
############################
data "aws_region"    "current" {}
data "aws_partition" "current" {}

############################
# Validations
############################
validation {
  condition     = contains(["ipv4","dualstack"], var.ip_address_type)
  error_message = "ip_address_type muss 'ipv4' oder 'dualstack' sein."
}
validation {
  condition     = contains(["TCP","UDP","TLS"], var.listener_protocol)
  error_message = "listener_protocol muss TCP|UDP|TLS sein."
}
validation {
  condition     = contains(["TCP","UDP","TLS"], var.tg_protocol)
  error_message = "tg_protocol muss TCP|UDP|TLS sein."
}
validation {
  condition     = length(var.subnet_ids) >= 2
  error_message = "subnet_ids sollte mindestens 2 Subnetze enthalten (pro AZ)."
}

############################
# Resources
############################
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "network"
  internal           = var.internal
  ip_address_type    = var.ip_address_type
  subnets            = var.subnet_ids
  security_groups    = [] # SG via Attachment-Ressource

  enable_cross_zone_load_balancing = var.enable_cross_zone
  deletion_protection_enabled      = var.deletion_protection

  tags = merge(var.tags, { Name = var.name })
}

# SG am NLB anhängen (wichtig für PrivateLink-Fluss)
resource "aws_lb_security_group_attachment" "nlb_sg" {
  load_balancer_arn = aws_lb.this.arn
  security_group_id = var.security_group_id
}

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
}

resource "aws_lb_listener" "tcp" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

############################
# Outputs
############################
output "nlb_arn"          { value = aws_lb.this.arn }
output "nlb_dns_name"     { value = aws_lb.this.dns_name }
output "nlb_zone_id"      { value = aws_lb.this.zone_id }
output "listener_arn"     { value = aws_lb_listener.tcp.arn }
output "target_group_arn" { value = aws_lb_target_group.this.arn }
