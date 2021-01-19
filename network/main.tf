provider "aws" {
  region = var.region
  profile= var.profile
}
terraform {
  backend "s3" {
    bucket         = "rds-test-terraform-state"
    key            = "development/network/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "rds-test-terraform-locks"
    encrypt        = true
    profile        = "XXXXXXXXX"
  }
}
data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block       = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = var.component
  }
}
resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name_prefix}-internet-gw"
  }
}
#------------------------------------------------------------------------------
# AWS Subnets - Public
#------------------------------------------------------------------------------
# Subnets
resource "aws_subnet" "public_subnets" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  availability_zone       = element(var.availability_zones, count.index)
  cidr_block              = element(var.public_subnets_cidrs_per_availability_zone, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name_prefix}-public-net-${element(var.availability_zones, count.index)}"
  }
}
# Elastic IPs for NAT
resource "aws_eip" "nat_eip" {
  count = length(var.availability_zones)
  vpc   = true
  tags = {
    Name = "${var.name_prefix}-nat-eip-${element(var.availability_zones, count.index)}"
  }
}
resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.availability_zones)
  depends_on    = [aws_internet_gateway.internet_gw]
  allocation_id = element(aws_eip.nat_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnets.*.id, count.index)
  tags = {
    Name = "${var.name_prefix}-nat-gw-${element(var.availability_zones, count.index)}"
  }
}

# Public route table
resource "aws_route_table" "public_subnets_route_table" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name_prefix}-public-rt-${element(var.availability_zones, count.index)}"
  }
}

# Public route to access internet
resource "aws_route" "public_internet_route" {
  count      = length(var.availability_zones)
  depends_on = [
    aws_internet_gateway.internet_gw,
    aws_route_table.public_subnets_route_table,
  ]
  route_table_id         = element(aws_route_table.public_subnets_route_table.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gw.id
}

# Association of Route Table to Subnets
resource "aws_route_table_association" "public_internet_route_table_associations" {
  count          = length(var.public_subnets_cidrs_per_availability_zone)
  subnet_id      = element(aws_subnet.public_subnets.*.id, count.index)
  route_table_id = element(aws_route_table.public_subnets_route_table.*.id, count.index)
}

resource "aws_subnet" "private_subnets" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  availability_zone       = element(var.availability_zones, count.index)
  cidr_block              = element(var.private_subnets_cidrs_per_availability_zone, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.name_prefix}-private-net-${element(var.availability_zones, count.index)}"
  }
}
# Private route table
resource "aws_route_table" "private_subnets_route_table" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name_prefix}-private-rt-${element(var.availability_zones, count.index)}"
  }
}
# Private route to access internet
resource "aws_route" "private_internet_route" {
  count      = length(var.availability_zones)
  depends_on = [
    aws_internet_gateway.internet_gw,
    aws_route_table.private_subnets_route_table,
  ]
  route_table_id         = element(aws_route_table.private_subnets_route_table.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat_gw.*.id, count.index)
}
# Association of Route Table to Subnets
resource "aws_route_table_association" "private_internet_route_table_associations" {
  count     = length(var.private_subnets_cidrs_per_availability_zone)
  subnet_id = element(aws_subnet.private_subnets.*.id, count.index)
  route_table_id = element(
    aws_route_table.private_subnets_route_table.*.id,
    count.index,
  )
}




