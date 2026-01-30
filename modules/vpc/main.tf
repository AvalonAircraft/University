# Module: Networking-Foundation (VPC & Endpoints)


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ... (Data Sources & Inputs bleiben wie von dir definiert) ...


# 1. Core VPC & Internet Gateway

resource "aws_vpc" "this" {
  cidr_block                       = var.cidr_block
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = var.create_ipv6
  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_egress_only_internet_gateway" "eigw" {
  count  = var.create_ipv6 && var.create_egress_only_igw ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-eigw" })
}


# 2. Subnets & NAT Gateways (High Availability)


# Public Subnets
resource "aws_subnet" "public" {
  for_each = {
    "a" = { cidr = var.public1_cidr, az = var.az_a },
    "b" = { cidr = var.public2_cidr, az = var.az_b }
  }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(var.tags, { Name = "${var.name}-public-${each.key}" })
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each = {
    "a" = { cidr = var.private1_cidr, az = var.az_a },
    "b" = { cidr = var.private2_cidr, az = var.az_b }
  }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

# NAT Gateways & EIPs (Einer pro AZ für Redundanz)
resource "aws_eip" "nat" {
  for_each = var.create_nat_gw ? toset(["a", "b"]) : []
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name}-nat-eip-${each.value}" })
}

resource "aws_nat_gateway" "this" {
  for_each      = var.create_nat_gw ? toset(["a", "b"]) : []
  allocation_id = aws_eip.nat[each.value].id
  subnet_id     = aws_subnet.public[each.value].id # NAT muss im Public Subnet liegen
  depends_on    = [aws_internet_gateway.igw]
  tags          = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })
}


# 3. Routing


# Public Routing
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-rt-public" })
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private Routing (Individuell pro AZ für NAT-Traffic)
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name}-rt-private-${each.key}" })
}

resource "aws_route" "private_nat_gw" {
  for_each               = var.create_nat_gw ? toset(["a", "b"]) : []
  route_table_id         = aws_route_table.private[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}


# 4. VPC Endpoints (S3 & Interfaces)


# S3 Gateway (Kostengünstig für internen S3 Traffic)
resource "aws_vpc_endpoint" "s3" {
  count             = var.create_s3_gateway_endpoint ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]
}

# Security Group für Interface Endpoints
resource "aws_security_group" "vpce" {
  count       = length(var.interface_endpoints) > 0 ? 1 : 0
  name        = "${var.name}-vpce-sg"
  vpc_id      = aws_vpc.this.id
  description = "Security group for VPC Endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.vpce_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Interface Endpoints (z.B. für SSM, ECR, SES)
resource "aws_vpc_endpoint" "interfaces" {
  for_each            = toset(var.interface_endpoints)
  vpc_id              = aws_vpc.this.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce[0].id]
}


# 5. VPC Flow Logs (Inkl. IAM)


resource "aws_iam_role" "flow_log_role" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.name}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  count = var.enable_flow_logs ? 1 : 0
  role  = aws_iam_role.flow_log_role[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Effect = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count           = var.enable_flow_logs ? 1 : 0
  iam_role_arn    = aws_iam_role.flow_log_role[0].arn
  log_destination = var.flow_logs_log_group_name != null ? var.flow_logs_log_group_name : aws_cloudwatch_log_group.flow[0].arn
  traffic_type    = var.flow_logs_traffic_type
  vpc_id          = aws_vpc.this.id
}

resource "aws_cloudwatch_log_group" "flow" {
  count             = var.enable_flow_logs && var.flow_logs_log_group_name == null ? 1 : 0
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = 30
}
