module "nlb" {
  source = "../../modules/nlb"

  name              = var.name
  vpc_id            = var.vpc_id
  subnet_ids        = [var.subnet_private1, var.subnet_private2]
  security_group_id = var.nlb_sg_id

  internal        = var.internal
  ip_address_type = var.ip_address_type

  tg_name        = var.tg_name
  tg_protocol    = var.tg_protocol
  tg_port        = var.service_port
  tg_target_type = "ip"

  listener_protocol = var.listener_protocol
  listener_port     = var.service_port

  # Health-Check
  hc_enabled       = var.hc_enabled
  hc_protocol      = var.hc_protocol
  hc_port          = var.hc_port
  hc_interval      = var.hc_interval
  hc_healthy_thr   = var.hc_healthy_thr
  hc_unhealthy_thr = var.hc_unhealthy_thr

  enable_cross_zone   = var.enable_cross_zone
  deletion_protection = var.deletion_protection

  tags = var.tags
}

output "nlb_arn"          { value = module.nlb.nlb_arn }
output "nlb_dns_name"     { value = module.nlb.nlb_dns_name }
output "nlb_zone_id"      { value = module.nlb.nlb_zone_id }
output "target_group_arn" { value = module.nlb.target_group_arn }
output "listener_arn"     { value = module.nlb.listener_arn }
