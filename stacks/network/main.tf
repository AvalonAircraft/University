############################
# VPC
############################
module "vpc" {
  source = "../../modules/vpc"

  name        = var.name
  cidr_block  = var.cidr_block
  create_ipv6 = var.create_ipv6

  az_a = var.az_a
  az_b = var.az_b

  public1_cidr  = var.public1_cidr
  public2_cidr  = var.public2_cidr
  private1_cidr = var.private1_cidr
  private2_cidr = var.private2_cidr

  create_nat_gw          = var.create_nat_gw
  create_egress_only_igw = var.create_egress_only_igw

  create_dhcp_options      = true
  dhcp_domain_name         = "ec2.internal"
  dhcp_domain_name_servers = ["AmazonProvidedDNS"]

  create_s3_gateway_endpoint        = var.create_s3_gateway_endpoint
  interface_endpoints               = var.interface_endpoints
  vpce_security_group_ingress_cidrs = var.vpce_security_group_ingress_cidrs

  tags = var.tags
}

############################
# Security Groups (mit VPC verbunden)
############################
module "sg" {
  source = "../../modules/security-groups"

  vpc_id        = module.vpc.vpc_id
  private1_cidr = var.private1_cidr
  private2_cidr = var.private2_cidr

  # neu: durchreichen (falls man später zentral pflegen will)
  lambda_vpce_ingress_cidrs = var.lambda_vpce_ingress_cidrs

  tags = var.tags
}

############################
# Outputs
############################
# VPC / Subnets / RTs
output "vpc_id"             { value = module.vpc.vpc_id }
output "subnet_public1_id"  { value = module.vpc.subnet_public1_id }
output "subnet_public2_id"  { value = module.vpc.subnet_public2_id }
output "subnet_private1_id" { value = module.vpc.subnet_private1_id }
output "subnet_private2_id" { value = module.vpc.subnet_private2_id }
output "rtb_public_id"      { value = module.vpc.rtb_public_id }
output "rtb_private1_id"    { value = module.vpc.rtb_private1_id }
output "rtb_private2_id"    { value = module.vpc.rtb_private2_id }
output "igw_id"             { value = module.vpc.igw_id }
output "eigw_id"            { value = module.vpc.eigw_id }
output "nat_gw_id_a"        { value = module.vpc.nat_gw_id_a }
output "nat_gw_id_b"        { value = module.vpc.nat_gw_id_b }
output "s3_endpoint_id"     { value = module.vpc.s3_endpoint_id }
output "vpce_interface_ids" { value = module.vpc.vpce_interface_ids }

# Security Groups
output "sg_aurora_id"                  { value = module.sg.sg_aurora_id }
output "sg_ecr_api_id"                 { value = module.sg.sg_ecr_api_id }
output "sg_ecs_fargate_id"             { value = module.sg.sg_ecs_fargate_id }
output "sg_lambda_agent_control_id"    { value = module.sg.sg_lambda_agent_control_id }
output "sg_lambda6_to_vpce_id"         { value = module.sg.sg_lambda6_to_vpce_id }
output "sg_secretsmanager_ep_id"       { value = module.sg.sg_secretsmanager_ep_id }
output "sg_nlb_fargate_privatelink_id" { value = module.sg.sg_nlb_fargate_privatelink_id }
output "sg_lambda_vpc_endpoint_id"     { value = module.sg.sg_lambda_vpc_endpoint_id }
