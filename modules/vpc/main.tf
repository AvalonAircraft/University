############################
# Inputs
############################
variable "name"        { type = string }
variable "cidr_block"  { type = string }
variable "create_ipv6" { type = bool }
variable "az_a"        { type = string }
variable "az_b"        { type = string }

variable "public1_cidr"  { type = string }
variable "public2_cidr"  { type = string }
variable "private1_cidr" { type = string }
variable "private2_cidr" { type = string }

# NAT & Egress
variable "create_nat_gw"          { type = bool }  # 2 NATs (pro AZ)
variable "create_egress_only_igw" { type = bool }  # ::/0 via EIGW auf Private-RTs

# DHCP Options
variable "create_dhcp_options"        { type = bool,   default = true }
variable "dhcp_domain_name"           { type = string, default = "ec2.internal" }
variable "dhcp_domain_name_servers"   { type = list(string), default = ["AmazonProvidedDNS"] }

# Endpoints
variable "create_s3_gateway_endpoint" { type = bool }
variable "interface_endpoints"        { type = list(string) }
variable "vpce_security_group_ingress_cidrs" { type = list(string) }

# Optional: Flow Logs (aus bis aktiviert)
variable "enable_flow_logs"        { type = bool,   default = false }
variable "flow_logs_traffic_type"  { type = string, default = "ALL" } # ACCEPT | REJECT | ALL
variable "flow_logs_log_group_name"{ type = string, default = null }  # wenn null → wird erzeugt

variable "tags" { type = map(string) }

############################
# Environment
############################
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  # Fallbacks/Guards
  vpce_ingress_cidrs = length(var.vpce_security_group_ingress_cidrs) > 0 ? var.vpce_security_group_ingress_cidrs : [var.cidr_block]
}

############################
# VPC
############################
resource "aws_vpc" "this" {
  cidr_block                       = var.cidr_block
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = var.create_ipv6
  tags = merge(var.tags, { Name = var.name })
}

############################
# Internet Gateway + (optional) Egress-Only-IGW
############################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_egress_only_internet_gateway" "eigw" {
  count  = var.create_ipv6 && var.create_egress_only_igw ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-eigw" })
}

############################
# DHCP Options
############################
resource "aws_vpc_dhcp_options" "this" {
  count               = var.create_dhcp_options ? 1 : 0
  domain_name         = var.dhcp_domain_name
  domain_name_servers = var.dhcp_domain_name_servers
  tags                = merge(var.tags, { Name = "${var.name}-dhcp" })
}

resource "aws_vpc_dhcp_options_association" "assoc" {
  count           = var.create_dhcp_options ? 1 : 0
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

############################
# Subnets (gehärtet: keine Auto-Public-IPs)
############################
resource "aws_subnet" "public1" {
  vpc_id                          = aws_vpc.this.id
  cidr_block                      = var.public1_cidr
  availability_zone               = var.az_a
  assign_ipv6_address_on_creation = false
  map_public_ip_on_launch         = false
  tags = merge(var.tags, { Name = "Projekt-subnet-public1-${var.az_a}" })
}

resource "aws_subnet" "public2" {
  vpc_id                          = aws_vpc.this.id
  cidr_block                      = var.public2_cidr
  availability_zone               = var.az_b
  assign_ipv6_address_on_creation = false
  map_public_ip_on_launch         = false
  tags = merge(var.tags, { Name = "Projekt-subnet-public2-${var.az_b}" })
}

resource "aws_subnet" "private1" {
  vpc_id                          = aws_vpc.this.id
  cidr_block                      = var.private1_cidr
  availability_zone               = var.az_a
  assign_ipv6_address_on_creation = false
  map_public_ip_on_launch         = false
  tags = merge(var.tags, { Name = "Projekt-subnet-private1-${var.az_a}" })
}

resource "aws_subnet" "private2" {
  vpc_id                          = aws_vpc.this.id
  cidr_block                      = var.private2_cidr
  availability_zone               = var.az_b
  assign_ipv6_address_on_creation = false
  map_public_ip_on_launch         = false
  tags = merge(var.tags, { Name = "Projekt-subnet-private2-${var.az_b}" })
}

############################
# Route Tables
############################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "Projekt-rtb-public" })
}

resource "aws_route" "public_ipv4_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "public_ipv6_default" {
  count                        = var.create_ipv6 ? 1 : 0
  route_table_id              = aws_route_table.public.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "pub1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "pub2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private1" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "Projekt-rtb-private1-${var.az_a}" })
}
resource "aws_route_table" "private2" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "Projekt-rtb-private2-${var.az_b}" })
}

# IPv6 ::/0 via EIGW (optional)
resource "aws_route" "priv1_ipv6_default" {
  count                       = var.create_ipv6 && var.create_egress_only_igw ? 1 : 0
  route_table_id              = aws_route_table.private1.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.eigw[0].id
}
resource "aws_route" "priv2_ipv6_default" {
  count                       = var.create_ipv6 && var.create_egress_only_igw ? 1 : 0
  route_table_id              = aws_route_table.private2.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.eigw[0].id
}

############################
# NAT pro AZ
############################
resource "aws_eip" "nat_a" {
  count  = var.create_nat_gw ? 1 : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-eip-${var.az_a}" })
}
resource "aws_eip" "nat_b" {
  count  = var.create_nat_gw ? 1 : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-eip-${var.az_b}" })
}

resource "aws_nat_gateway" "nat_a" {
  count         = var.create_nat_gw ? 1 : 0
  allocation_id = aws_eip.nat_a[0].id
  subnet_id     = aws_subnet.public1.id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${var.az_a}" })
  depends_on    = [aws_internet_gateway.igw]
}
resource "aws_nat_gateway" "nat_b" {
  count         = var.create_nat_gw ? 1 : 0
  allocation_id = aws_eip.nat_b[0].id
  subnet_id     = aws_subnet.public2.id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${var.az_b}" })
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route" "priv1_ipv4_default" {
  count                  = var.create_nat_gw ? 1 : 0
  route_table_id         = aws_route_table.private1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a[0].id
}
resource "aws_route" "priv2_ipv4_default" {
  count                  = var.create_nat_gw ? 1 : 0
  route_table_id         = aws_route_table.private2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_b[0].id
}

resource "aws_route_table_association" "priv1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private1.id
}
resource "aws_route_table_association" "priv2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private2.id
}

############################
# VPC Endpoints
############################
# S3 Gateway → Private-RTs
resource "aws_vpc_endpoint" "s3" {
  count             = var.create_s3_gateway_endpoint ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private1.id, aws_route_table.private2.id]
  tags              = merge(var.tags, { Name = "${var.name}-vpce-s3" })
}

# SG für Interface-VPCEs
resource "aws_security_group" "vpce" {
  count       = length(var.interface_endpoints) > 0 ? 1 : 0
  name        = "${var.name}-vpce-sg"
  description = "HTTPS from VPC to Interface Endpoints"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name}-vpce-sg" })

  dynamic "ingress" {
    for_each = local.vpce_ingress_cidrs
    content {
      description = "HTTPS from ${ingress.value}"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "All"
  }
}

# Interface-VPCEs (in PRIVATE Subnets)
resource "aws_vpc_endpoint" "interfaces" {
  for_each             = toset(var.interface_endpoints)
  vpc_id               = aws_vpc.this.id
  service_name         = each.value
  vpc_endpoint_type    = "Interface"
  subnet_ids           = [aws_subnet.private1.id, aws_subnet.private2.id]
  private_dns_enabled  = true
  security_group_ids   = length(var.interface_endpoints) > 0 ? [aws_security_group.vpce[0].id] : null
  tags = merge(var.tags, {
    Name = "${var.name}-vpce-${replace(each.value, "com.amazonaws.${data.aws_region.current.name}.", "")}"
  })
}

############################
# (Optional) Flow Logs – CloudWatch Logs
############################
resource "aws_cloudwatch_log_group" "flow" {
  count             = var.enable_flow_logs && var.flow_logs_log_group_name == null ? 1 : 0
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_flow_log" "vpc" {
  count                = var.enable_flow_logs ? 1 : 0
  log_destination_type = "cloud-watch-logs"
  log_group_name       = var.flow_logs_log_group_name != null ? var.flow_logs_log_group_name : aws_cloudwatch_log_group.flow[0].name
  traffic_type         = var.flow_logs_traffic_type
  vpc_id               = aws_vpc.this.id
  # Hinweis: Du brauchst IAM-Berechtigungen für FlowLogs→CloudWatch (normalerweise über Service-Linked Role abgedeckt)
  tags = merge(var.tags, { Name = "${var.name}-flow-logs" })
}

############################
# Outputs
############################
output "vpc_id"             { value = aws_vpc.this.id }
output "subnet_public1_id"  { value = aws_subnet.public1.id }
output "subnet_public2_id"  { value = aws_subnet.public2.id }
output "subnet_private1_id" { value = aws_subnet.private1.id }
output "subnet_private2_id" { value = aws_subnet.private2.id }
output "rtb_public_id"      { value = aws_route_table.public.id }
output "rtb_private1_id"    { value = aws_route_table.private1.id }
output "rtb_private2_id"    { value = aws_route_table.private2.id }
output "igw_id"             { value = aws_internet_gateway.igw.id }
output "eigw_id"            { value = var.create_ipv6 && var.create_egress_only_igw ? aws_egress_only_internet_gateway.eigw[0].id : null }
output "nat_gw_id_a"        { value = var.create_nat_gw ? aws_nat_gateway.nat_a[0].id : null }
output "nat_gw_id_b"        { value = var.create_nat_gw ? aws_nat_gateway.nat_b[0].id : null }
output "s3_endpoint_id"     { value = var.create_s3_gateway_endpoint ? aws_vpc_endpoint.s3[0].id : null }
output "vpce_interface_ids" { value = [for k, v in aws_vpc_endpoint.interfaces : v.id] }
