data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    # Replace this with your bucket name!
    bucket = "${var.project}-terraform-state"
    key    = "${var.environment}/network/terraform.tfstate"
    region = var.region
    profile  = var.profile
  }
}
data "terraform_remote_state" "fargate" {
  backend = "s3"
  config = {
    # Replace this with your bucket name!
    bucket = "${var.project}-terraform-state"
    key    = "${var.environment}/fargate/terraform.tfstate"
    region = var.region
    profile  = var.profile
  }
}
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-cluster"
  engine               = "redis"
  node_type            = var.instance_type
  num_cache_nodes      = 1
  parameter_group_name = var.parameter_group_name
  engine_version       = var.engine_version
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

