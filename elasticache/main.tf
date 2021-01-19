provider "aws" {
  region = var.region
  profile= var.profile
}
terraform {
  backend "s3" {
    bucket         = "rds-test-terraform-state"
    key            = "development/elasticache/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "rds-test-terraform-locks"
    encrypt        = true
    profile        = "test-acct-1-admin"
  }
}

module "elasticache_cluster" {
  source = "../modules/elasticache"
  project = "rds-test"
  environment = "development"
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    # Replace this with your bucket name!
    bucket = "rds-test-terraform-state"
    key    = "development/network/terraform.tfstate"
    region = "us-east-2"
    profile  = "test-acct-1-admin"
  }
}
data "terraform_remote_state" "fargate" {
  backend = "s3"
  config = {
    # Replace this with your bucket name!
    bucket = "rds-test-terraform-state"
    key    = "development/fargate/terraform.tfstate"
    region = "us-east-2"
    profile  = "test-acct-1-admin"
  }
}
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-cluster"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis5.0"
  engine_version       = "5.0.6"
  port                 = 6379
  security_group_ids = [aws_security_group.elasticache_sg.id]
  subnet_group_name = aws_elasticache_subnet_group.cache_subnet_group.id
}
resource "aws_elasticache_subnet_group" "cache_subnet_group" {
  name       = "tf-test-cache-subnet"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnets_ids
}
resource "aws_security_group" "elasticache_sg" {
  name        = "${var.project}-elasticache-sg"
  description = "Allow inbound access from the container"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project}-elasticache-sg"
  }
}


