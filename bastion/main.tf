provider "aws" {
  region = var.region
  profile= var.profile
}
terraform {
  backend "s3" {
    bucket         = "rds-test-terraform-state"
    key            = "development/bastion/terraform.tfstate"
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
data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    # Replace this with your bucket name!
    bucket = "rds-test-terraform-state"
    key    = "development/datastore/terraform.tfstate"
    region = "us-east-2"
    profile  = "test-acct-1-admin"
  }
}
data "http" "myip" {
   url = "http://icanhazip.com"
}
data "aws_ami" "amazon-linux-2" {
 most_recent = true
  owners = ["amazon"]

 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }
}
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  subnet_id = data.terraform_remote_state.network.outputs.public_subnets_ids[0]
  key_name = "test-acct-1"
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_instance_profile.id
}
resource "aws_instance" "private_bastion" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  subnet_id = data.terraform_remote_state.network.outputs.private_subnets_ids[0]
  key_name = "test-acct-1"
  vpc_security_group_ids = [aws_security_group.private_bastion_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_instance_profile.id
}
resource "aws_vpc_endpoint" "ssm_messages" {

  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id

  service_name      = "com.amazonaws.${var.region}.ssmmessages"

  vpc_endpoint_type = "Interface"

  subnet_ids = data.terraform_remote_state.network.outputs.private_subnets_ids

  security_group_ids = [ aws_security_group.endpoints_sg.id ]

  private_dns_enabled = true

}
resource "aws_vpc_endpoint" "ec2messages" {

  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id

  service_name      = "com.amazonaws.${var.region}.ec2messages"

  vpc_endpoint_type = "Interface"

  subnet_ids = data.terraform_remote_state.network.outputs.private_subnets_ids

  security_group_ids = [ aws_security_group.endpoints_sg.id ]

  private_dns_enabled = true

}

resource "aws_vpc_endpoint" "ssm" {

  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id

  service_name      = "com.amazonaws.${var.region}.ssm"

  vpc_endpoint_type = "Interface"

  subnet_ids = data.terraform_remote_state.network.outputs.private_subnets_ids

  security_group_ids = [ aws_security_group.endpoints_sg.id ]

  private_dns_enabled = true

}
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-bastion-ssm-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
}
}
EOF
}
resource "aws_iam_instance_profile" "ec2_ssm_instance_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
resource "aws_iam_role_policy_attachment" "test_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_security_group" "endpoints_sg"{
  name = "endpoints-ssm-sg"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}
resource "aws_security_group_rule" "allow_endpoints_443_from_bastion" {
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  source_security_group_id = aws_security_group.private_bastion_sg.id
  security_group_id = aws_security_group.endpoints_sg.id
}
resource "aws_security_group_rule" "allow_endpoints_443_to_bastion" {
  type = "egress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  source_security_group_id = aws_security_group.private_bastion_sg.id
  security_group_id = aws_security_group.endpoints_sg.id
}
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project}-bastion-sg"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  tags = {
    Name = "${var.project}-mysql-sg"
  }
}
resource "aws_security_group" "private_bastion_sg" {
  name        = "${var.project}-private-bastion-sg"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    protocol = "tcp"
    to_port = 443
    security_groups = [aws_security_group.endpoints_sg.id]
  }
  tags = {
    Name = "${var.project}-mysql-sg"
  }
}
data template_file circleci_json {
  template = file("${path.module}/circleci.tmpl")
  vars = {
    id = aws_instance.private_bastion.id
  }
}
resource "null_resource" "circle_ci" {
  depends_on = [aws_instance.private_bastion]
  triggers = {
    //bastion_name = md5(aws_instance.private_bastion.id)
    timestamp = timestamp()
  }
  provisioner "local-exec" {
    command = "curl --header 'Content-Type: application/json' --header 'Circle-Token: ${var.circleci_token}' --header 'Accept: application/json' --data '${data.template_file.circleci_json.rendered}' --request POST https://circleci.com/api/v2/project/github/kmccanless/ssm-ssh-tunnel/envvar"
    }
}
resource "aws_security_group_rule" "mysql_sg_ingress" {
  security_group_id        = data.terraform_remote_state.rds.outputs.database_sg
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
}
resource "aws_security_group_rule" "mysql_sg_ingress_from_private" {
  security_group_id        = data.terraform_remote_state.rds.outputs.database_sg
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.private_bastion_sg.id
}