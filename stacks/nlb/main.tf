module "nlb" {
  source = "../../modules/nlb"

  name              = "nlb-fargate"
  vpc_id            = var.vpc_id
  subnet_ids        = [var.subnet_private1, var.subnet_private2]
  security_group_id = var.nlb_sg_id

  internal        = true
  ip_address_type = "dualstack"

  tg_name        = "fargate-nlb-targets"
  tg_protocol    = "TCP"
  tg_port        = 8080
  tg_target_type = "ip"

  listener_protocol = "TCP"
  listener_port     = 8080

  # Health-Check (TCP)
  hc_enabled       = true
  hc_protocol      = "TCP"
  hc_port          = "traffic-port"
  hc_interval      = 10
  hc_healthy_thr   = 3
  hc_unhealthy_thr = 3

  # Optional Hardening/Perf
  enable_cross_zone   = true
  deletion_protection = false

  tags = var.tags
}

output "nlb_arn"          { value = module.nlb.nlb_arn }
output "nlb_dns_name"     { value = module.nlb.nlb_dns_name }   # z.B. nlb-fargate-....elb.us-east-1.amazonaws.com
output "nlb_zone_id"      { value = module.nlb.nlb_zone_id }     # z.B. Z26RNL4JYFTOTI
output "target_group_arn" { value = module.nlb.target_group_arn }
output "listener_arn"     { value = module.nlb.listener_arn }
