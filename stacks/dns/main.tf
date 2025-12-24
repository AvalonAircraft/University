module "route53" {
  source      = "../../modules/route53"
  create_zone = var.create_zone
  zone_name   = var.zone_name
  records     = var.dns_records
}

output "zone_id"      { value = module.route53.zone_id }
output "zone_name"    { value = module.route53.zone_name }
output "name_servers" { value = module.route53.name_servers }
