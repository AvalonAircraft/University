module "sg" {
  source        = "../../modules/security-groups"

  vpc_id        = var.vpc_id
  private1_cidr = var.private1_cidr
  private2_cidr = var.private2_cidr

  # Übergabe AWS-IP-Ranges für Lambda VPCE
  lambda_vpce_ingress_cidrs = var.lambda_vpce_ingress_cidrs

  # Optional: IPv6 intern zulassen
  # enable_ipv6_ingress = true

  tags = var.tags
}

output "sg_aurora_id"                  { value = module.sg.sg_aurora_id }
output "sg_ecr_api_id"                 { value = module.sg.sg_ecr_api_id }
output "sg_ecs_fargate_id"             { value = module.sg.sg_ecs_fargate_id }
output "sg_lambda_agent_control_id"    { value = module.sg.sg_lambda_agent_control_id }
output "sg_lambda6_to_vpce_id"         { value = module.sg.sg_lambda6_to_vpce_id }
output "sg_secretsmanager_ep_id"       { value = module.sg.sg_secretsmanager_ep_id }
output "sg_nlb_fargate_privatelink_id" { value = module.sg.sg_nlb_fargate_privatelink_id }
output "sg_lambda_vpc_endpoint_id"     { value = module.sg.sg_lambda_vpc_endpoint_id }
