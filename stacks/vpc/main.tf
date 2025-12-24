provider "aws" {
  region = var.region
}

data "aws_region" "current" {}

locals {
  svc_prefix = "com.amazonaws.${var.region}"

  default_interface_endpoints = [
    "${local.svc_prefix}.lambda",
    "${local.svc_prefix}.secretsmanager",
    "${local.svc_prefix}.ecr.api",
    "${local.svc_prefix}.ecr.dkr",
    "${local.svc_prefix}.logs",
    "${local.svc_prefix}.kms",
    "${local.svc_prefix}.bedrock-runtime",
    "${local.svc_prefix}.comprehend",
    "${local.svc_prefix}.events",
  ]

  effective_interface_endpoints = (
    var.interface_endpoints == null || length(var.interface_endpoints) == 0
  ) ? local.default_interface_endpoints : var.interface_endpoints

  effective_vpce_ingress_cidrs = (
    length(var.vpce_security_group_ingress_cidrs) == 0
  ) ? [var.cidr_block] : var.vpce_security_group_ingress_cidrs
}

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

  create_dhcp_options      = var.create_dhcp_options
  dhcp_domain_name         = var.dhcp_domain_name
  dhcp_domain_name_servers = var.dhcp_domain_name_servers

  create_s3_gateway_endpoint        = var.create_s3_gateway_endpoint
  interface_endpoints               = local.effective_interface_endpoints
  vpce_security_group_ingress_cidrs = local.effective_vpce_ingress_cidrs

  # Optional: Flow Logs durchreichen
  enable_flow_logs         = var.enable_flow_logs
  flow_logs_traffic_type   = var.flow_logs_traffic_type
  flow_logs_log_group_name = var.flow_logs_log_group_name

  tags = var.tags
}

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
