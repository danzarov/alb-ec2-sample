provider "aws" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # canonical id
}

resource "aws_launch_configuration" "launch_configuration_ubuntu" {
  name_prefix   = "launch_configuration_ubuntu"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }

  security_groups = [aws_security_group.launch_config_security_group.id]

  user_data = <<-EOF
              #!/bin/bash
              touch /tmp/filetest.txt
              sudo apt-get install nginx -y
              echo 'launch config sample 1' > /var/www/html/index.html
              sudo systemctl --now enable nginx
              EOF
}

# get default vpc
data "aws_vpc" "selected" {
  default = true
}

resource "aws_security_group" "launch_config_security_group" {
  vpc_id      = data.aws_vpc.selected.id
  name        = "launch_config_security_group"
  description = "security group for launch config"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name        = "danny_vpc_security_group"
    description = "security group for the launch config instances"
  }
}

data "aws_subnet_ids" "example" {
  vpc_id = data.aws_vpc.selected.id
}

data "aws_subnet" "example" {
  for_each = data.aws_subnet_ids.example.ids
  id       = each.value
}


resource "aws_autoscaling_group" "asg-sample" {
  name                 = "asg-sample"
  launch_configuration = aws_launch_configuration.launch_configuration_ubuntu.id
  min_size             = 1
  max_size             = 2
  desired_capacity     = 2

  vpc_zone_identifier = [for s in data.aws_subnet.example : s.id]
  target_group_arns   = [aws_lb_target_group.target_group_sample.arn] # all ec2 instances created here will be associated with the target group

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns]
  }

  wait_for_capacity_timeout = "15m"
}


# create target group
resource "aws_lb_target_group" "target_group_sample" {
  name     = "target-group-sample"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id
}

# create elb (ALB) type
resource "aws_lb" "alb_sample" {
  name               = "alb-sample"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [for s in data.aws_subnet.example : s.id]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb_sample.arn
  port              = "80"
  protocol          = "HTTP"
  #ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_sample.arn
  }
}

# alb security group
resource "aws_security_group" "alb_security_group" {
  vpc_id      = data.aws_vpc.selected.id
  name        = "alb_security_group"
  description = "security group for the alb"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name        = "alb_security_group"
    description = "security group for the alb"
  }
}