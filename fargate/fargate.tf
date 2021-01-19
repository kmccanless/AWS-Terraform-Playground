provider "aws" {
  region = var.region
  profile= var.profile
}
terraform {
  backend "s3" {
    bucket         = "rds-test-terraform-state"
    key            = "development/fargate/terraform.tfstate"
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
data "terraform_remote_state" "elasticache" {
  backend = "s3"
  config = {
    # Replace this with your bucket name!
    bucket = "rds-test-terraform-state"
    key    = "development/elasticache/terraform.tfstate"
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
resource "aws_ecs_cluster" "cluster" {
  name = "test-cluster"
  capacity_providers = ["FARGATE"]
}
#------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
#------------------------------------------------------------------------------
resource "aws_lb" "lb" {
  name                             = "${var.project}-lb"
  internal                         = false
  load_balancer_type               = "application"
  subnets                          = data.terraform_remote_state.network.outputs.public_subnets_ids
  idle_timeout                     = var.idle_timeout
  enable_deletion_protection       = false
  enable_http2                     = false
  ip_address_type                  = "ipv4"
  security_groups                  = [aws_security_group.lb_access_sg.id]

  # TODO - Enable this feature
  # access_logs {
  #   bucket  = aws_s3_bucket.logs.id
  #   prefix  = ""
  #   enabled = true
  # }
  tags = {
    Name = "${var.project}-lb"
  }
}

#------------------------------------------------------------------------------
# ACCESS CONTROL TO APPLICATION LOAD BALANCER
#------------------------------------------------------------------------------
resource "aws_security_group" "lb_access_sg" {
  name        = "${var.project}-lb-access-sg"
  description = "Controls access to the Load Balancer"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project}-lb-access-sg"
  }
}

resource "aws_security_group_rule" "ingress_through_http" {
  security_group_id = aws_security_group.lb_access_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "ingress_through_https" {
  security_group_id = aws_security_group.lb_access_sg.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
#------------------------------------------------------------------------------
# AWS LOAD BALANCER - Target Groups
#------------------------------------------------------------------------------
resource "aws_lb_target_group" "lb_http_tgs" {
  name                          = "${var.project}-lb-http-tg"
  port                          = 80
  protocol                      = "HTTP"
  vpc_id                        = data.terraform_remote_state.network.outputs.vpc_id
   health_check {
    enabled = true
  }
  target_type = "ip"
  tags = {
    Name = "${var.project}-lb-http-tg"
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [ aws_lb.lb ]
}

#------------------------------------------------------------------------------
# AWS LOAD BALANCER - Listeners
#------------------------------------------------------------------------------
resource "aws_lb_listener" "lb_http_listeners" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.lb_http_tgs.id
    type             = "forward"
  }
}
resource "aws_lb_listener" "lb_https_listeners" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  default_action {
    target_group_arn = aws_lb_target_group.lb_http_tgs.id
    type             = "forward"
  }
}
#------------------------------------------------------------------------------
# AWS ECS Task Execution Role
#------------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project}-ecs-task-execution-role"
  assume_role_policy = file("${path.module}/files/iam/ecs_task_execution_iam_role.json")
}

resource "aws_iam_policy" "ecs_policy" {
  name = "${var.project}-ecs-policy"
  policy = file("${path.module}/files/iam/ecs_iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_policy.arn
}

# Task Definition
resource "aws_ecs_task_definition" "td" {
  family                = "${var.project}-td"
  container_definitions = <<TASK_DEFINITION
  [{
			"essential": true,
			"image": "906394416424.dkr.ecr.us-east-2.amazonaws.com/aws-for-fluent-bit:latest",
			"name": "log_router",
			"firelensConfiguration": {
				"type": "fluentbit",
                "options": {
			        "enable-ecs-log-metadata": "false"
                }
			},
			"logConfiguration": {
				"logDriver": "awslogs",
				"options": {
					"awslogs-group": "firelens-container",
					"awslogs-region": "us-east-2",
					"awslogs-create-group": "true",
					"awslogs-stream-prefix": "firelens"
				}
			},
			"memoryReservation": 50
		 },
      {
        "name": "${var.container_name}",
        "image": "${var.image_name}",
        "environment" : [
          {
                "name": "REDIS_HOST",
                "value": "${data.terraform_remote_state.elasticache.outputs.elasticache_address}"
          },
          {
                "name": "REDIS_PORT",
                "value": "${data.terraform_remote_state.elasticache.outputs.elasticache_port}"
          }
        ],
        "essential": true,
        "portMappings": [
          {
            "containerPort": 5000,
            "hostPort": 5000
          }
        ],
        "logConfiguration": {
          "logDriver": "awsfirelens",
          "options": {
			"Name": "cloudwatch",
			"region": "us-east-2",
			"log_key": "log",
			"log_group_name": "/aws/ecs/containerinsights/$(ecs_cluster)/application",
			"auto_create_group": "true",
			"log_stream_name": "test-stream"
		}
        }
      }
  ]
  TASK_DEFINITION
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
}

resource "aws_ecs_service" "service" {
  name                               = "${var.project}-service"
  cluster                            = aws_ecs_cluster.cluster.id
  desired_count                      = 1
  health_check_grace_period_seconds  = 30
  launch_type                        = "FARGATE"
  force_new_deployment               = true
  load_balancer {
    target_group_arn = aws_lb_target_group.lb_http_tgs.arn
    container_name = var.container_name
    container_port = 5000
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.lb_http_tgs.arn
    container_name = var.container_name
    container_port = 5000
  }
  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    subnets          = data.terraform_remote_state.network.outputs.public_subnets_ids
    assign_public_ip = true
  }
  task_definition = aws_ecs_task_definition.td.arn
  tags = {
    Name = "${var.project}-ecs-tasks-sg"
  }
}

#------------------------------------------------------------------------------
# AWS SECURITY GROUP - ECS Tasks, allow traffic only from Load Balancer
#------------------------------------------------------------------------------
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${var.project}-ecs-tasks-sg"
  description = "Allow inbound access from the LB only"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 5000
    protocol = "tcp"
    to_port = 5000
    security_groups = [aws_security_group.lb_access_sg.id]
  }
  tags = {
    Name = "${var.project}-ecs-tasks-sg"
  }
}

resource "aws_route53_record" "a_record" {
  zone_id = var.zone_id
  name = "mccanless.rocks"
  type = "A"
  alias {
    evaluate_target_health = true
    name = aws_lb.lb.dns_name
    zone_id = aws_lb.lb.zone_id
  }
}
resource "aws_security_group_rule" "elasticache_sg_ingress" {
  security_group_id        = data.terraform_remote_state.elasticache.outputs.elasticache_sg
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks_sg.id
}

//resource "aws_security_group_rule" "mysql_sg_ingress" {
//  security_group_id        = data.terraform_remote_state.rds.outputs.cluster_sg[0]
//  type                     = "ingress"
//  from_port                = 3306
//  to_port                  = 3306
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.ecs_tasks_sg.id
//}
resource "aws_cloudwatch_event_rule" "ecs_stopped" {
  name        = "ecs-task-stopped"
  description = "Capture ecs tasks stopping"

  event_pattern = <<EOF
    {
       "source":[
          "aws.ecs"
       ],
       "detail-type":[
          "ECS Task State Change"
       ],
       "detail":{
          "lastStatus":[
             "STOPPED"
          ],
          "stoppedReason":[
             "Essential container in task exited"
          ]
       }
    }
    EOF
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.ecs_stopped.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.ecs_stopped_tasks.arn
}

resource "aws_sns_topic" "ecs_stopped_tasks" {
  name = "ecs-task-stopped"
}
resource "aws_sns_topic_subscription" "ecs_task_stopped_target" {
  topic_arn = aws_sns_topic.ecs_stopped_tasks.arn
  protocol  = "sms"
  endpoint  = "+16142268308"
}
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.ecs_stopped_tasks.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.ecs_stopped_tasks.arn]
  }
}