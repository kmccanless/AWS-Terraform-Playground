provider "aws" {
  region = var.region
  profile= var.profile
}
terraform {
  backend "s3" {
    bucket         = "rds-test-terraform-state"
    key            = "development/datastore/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "rds-test-terraform-locks"
    encrypt        = true
    profile        = "test-acct-1-admin"
  }
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
module "rds_cluster_aurora_mysql_serverless" {
  source               = "git::https://github.com/cloudposse/terraform-aws-rds-cluster.git?ref=tags/0.31.0"
  namespace            = var.namespace
  stage                = var.environment
  name                 = var.component
  engine               = "aurora-mysql"
  engine_mode          = "serverless"
  engine_version       = "5.7.mysql_aurora.2.07.1"
  cluster_size         = "0"
  cluster_family       = "aurora-mysql5.7"
  admin_user           = var.db_username
  admin_password       = var.db_password
  db_name              = var.db_name
  db_port              = "3306"
  instance_type        = var.instance_type
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  security_groups      = []
  vpc_security_group_ids  = [aws_security_group.mysql_sg.id]
  subnets              = data.terraform_remote_state.network.outputs.private_subnets_ids
  enable_http_endpoint = true
  scaling_configuration = [
    {
      auto_pause               = true
      max_capacity             = var.max_capacity
      min_capacity             = var.min_capacity
      seconds_until_auto_pause = 300
      timeout_action           = "RollbackCapacityChange"
    }
  ]
}
resource "aws_security_group" "mysql_sg" {
  name        = "${var.project}-mysql-sg"
  description = "Allow inbound access from the container to mysql"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project}-mysql-sg"
  }
}