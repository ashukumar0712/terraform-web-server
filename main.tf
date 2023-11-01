terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

locals {
  num_subnets = length(var.availability_zones)
}

provider "aws" {
  region  = var.region
}

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name = "vpc-${var.suffix}"
  }
}

resource "aws_subnet" "subnet" {
  count             = local.num_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 3 + count.index * 2)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "subnet-${var.suffix}"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "gateway-${var.suffix}"
  }
}

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "routetable-${var.suffix}"
  }
}

resource "aws_route_table_association" "subnet-association" {
  count          = local.num_subnets
  subnet_id      = aws_subnet.subnet[count.index].id
  route_table_id = aws_route_table.routetable.id
}

resource "aws_security_group" "main" {
  vpc_id = aws_vpc.vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { "Name" = "sg-${var.suffix}" }
}

resource "aws_security_group_rule" "ingress_rules" {
  count             = length(var.security_rules)
  type              = "ingress"
  security_group_id = aws_security_group.main.id
  protocol          = var.security_rules[count.index].protocol
  description       = var.security_rules[count.index].description
  from_port         = var.security_rules[count.index].from_port
  to_port           = var.security_rules[count.index].to_port
  cidr_blocks       = var.security_rules[count.index].cidr_blocks
}

resource "aws_lb" "web-alb" {
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.main.id]
  subnets            = [for subnet in aws_subnet.subnet : subnet.id]

  tags = {
    Name = "web-lb-${var.suffix}"
  }
}

resource "aws_lb_target_group" "web-lb-tg" {
  target_type  = "instance"
  port         = 80
  protocol     = "HTTP"
  vpc_id       = aws_vpc.vpc.id
  
  health_check {
    protocol = "HTTP"
    path     = "/index.html"
    port     = 80
  }

  tags = { "Name" = "lb-tg-${var.suffix}" }
}

resource "aws_lb_listener" "web-alb-listner" {

  load_balancer_arn = aws_lb.web-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web-lb-tg.arn
  }
}

resource "aws_key_pair" "TF_key" {
  key_name   = "key-pair-${var.suffix}"
  public_key = tls_private_key.rsa.public_key_openssh
  tags       = { "Name" = "key-pair-${var.suffix}" }
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Creates and stores ssh key used creating an EC2 instance
resource "aws_secretsmanager_secret" "secret" {
  name = "secret-${var.suffix}"
}

resource "aws_launch_template" "web-lt" {
  name = "lt-${var.suffix}"
  image_id = var.ami
  instance_type = var.instancetype
  key_name = aws_key_pair.TF_key.key_name

  vpc_security_group_ids = [aws_security_group.main.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-test-${var.suffix}"
    }
  }

  user_data = filebase64("install_web.sh")
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web-asg" {
  name                      = "asg-${var.suffix}"
  max_size                  = 2
  min_size                  = 2
  desired_capacity          = 2
  health_check_type         = "ELB"
  launch_template {
    id = aws_launch_template.web-lt.id
  }

  vpc_zone_identifier       = [for subnet in aws_subnet.subnet : subnet.id]

  tag {
    key                 = "Name"
    value               = "asg-${var.suffix}"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Create a new load balancer attachment
resource "aws_autoscaling_attachment" "asg-attachment-web" {
  autoscaling_group_name = aws_autoscaling_group.web-asg.id
  lb_target_group_arn    = aws_lb_target_group.web-lb-tg.id
}



