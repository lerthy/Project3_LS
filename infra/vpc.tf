# Local variables for VPC
locals {
  primary_azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  standby_azs = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

# Primary VPC in us-east-1
module "primary_vpc" {
  source = "./modules/vpc"

  environment          = "primary"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones   = local.primary_azs
  tags                 = local.common_tags
}

# Standby VPC in us-west-2
module "standby_vpc" {
  source = "./modules/vpc"
  providers = {
    aws = aws.standby
  }

  environment          = "standby"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
  availability_zones   = local.standby_azs
  tags                 = local.common_tags
}

# VPC Peering for cross-region communication
resource "aws_vpc_peering_connection" "primary_to_standby" {
  vpc_id      = module.primary_vpc.vpc_id
  peer_vpc_id = module.standby_vpc.vpc_id
  peer_region = var.standby_region
  auto_accept = false

  tags = merge(local.common_tags, {
    Name = "primary-to-standby-peering"
  })
}

# Accept VPC peering connection in standby region
resource "aws_vpc_peering_connection_accepter" "standby" {
  provider                  = aws.standby
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_standby.id
  auto_accept               = true

  tags = merge(local.common_tags, {
    Name = "standby-peering-accepter"
  })
}

# Update route tables for VPC peering
resource "aws_route" "primary_to_standby_private" {
  count                     = length(module.primary_vpc.private_subnet_ids)
  route_table_id            = module.primary_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.standby_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_standby.id
}

resource "aws_route" "standby_to_primary_private" {
  provider                  = aws.standby
  count                     = length(module.standby_vpc.private_subnet_ids)
  route_table_id            = module.standby_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.primary_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_standby.id
}