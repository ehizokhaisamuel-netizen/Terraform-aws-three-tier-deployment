# Builds: VPC, 4 subnet tiers (public, web, app, data) x N AZs,
# Internet Gateway, one NAT Gateway, and route tables.
# Matches the architecture diagram's WEB TIER / APP TIER / DATA TIER layout.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

locals {
  az_map = { for idx, az in var.azs : az => idx }
}

resource "aws_subnet" "public" {
  for_each                = local.az_map
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block               = cidrsubnet(var.vpc_cidr, 8, each.value)        # 10.0.0.0/24, .1.0/24, .2.0/24
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-${each.key}" }
}

resource "aws_subnet" "web_private" {
  for_each          = local.az_map
  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 10)          # 10.0.10.0/24, .11.0/24, .12.0/24
  tags = { Name = "${var.project_name}-web-${each.key}" }
}

resource "aws_subnet" "app_private" {
  for_each          = local.az_map
  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 20)          # 10.0.20.0/24, .21.0/24, .22.0/24
  tags = { Name = "${var.project_name}-app-${each.key}" }
}

resource "aws_subnet" "data_private" {
  for_each          = local.az_map
  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 30)          # 10.0.30.0/24, .31.0/24, .32.0/24
  tags = { Name = "${var.project_name}-data-${each.key}" }
}

# One NAT Gateway, in the first AZ's public subnet — matches the diagram.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[var.azs[0]].id
  tags          = { Name = "${var.project_name}-nat" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "web_private" {
  for_each       = aws_subnet.web_private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_private" {
  for_each       = aws_subnet.app_private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data_private" {
  for_each       = aws_subnet.data_private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
