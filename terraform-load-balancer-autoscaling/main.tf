terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Sử dụng VPC và subnet từ bài 3 (giả định đã có sẵn, hoặc bạn có thể tạo lại)
data "aws_vpc" "my_vpc" {
  filter {
    name   = "tag:Name"
    values = ["MyVPC"]
  }
}

data "aws_subnet" "my_subnet" {
  filter {
    name   = "tag:Name"
    values = ["MySubnet"]
  }
}

# Tạo Security Group cho EC2 và Load Balancer
resource "aws_security_group" "web_sg" {
  vpc_id = data.aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebSecurityGroup"
  }
}

# Tạo Launch Template cho Auto Scaling Group
resource "aws_launch_template" "web_template" {
  name_prefix   = "web-template-"
  image_id      = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 in us-east-1
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  user_data = base64encode(<<-EOF
  #!/bin/bash
  yum update -y
  yum install -y httpd
  systemctl start httpd
  systemctl enable httpd
  echo "
<h1>Hello from Terraform Auto Scaling Group!</h1>" > /var/www/html/index.html
  EOF
  )

  tags = {
    Name = "WebInstance"
  }
}

# Tạo Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity = 2
  min_size         = 1
  max_size         = 3
  vpc_zone_identifier = [data.aws_subnet.my_subnet.id]

  launch_template {
    id      = aws_launch_template.web_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "WebASGInstance"
    propagate_at_launch = true
  }
}

# Tạo Application Load Balancer
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [data.aws_subnet.my_subnet.id]

  tags = {
    Name = "WebLoadBalancer"
  }
}

# Tạo Target Group cho Load Balancer
resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.my_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Tạo Listener cho Load Balancer
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Gắn Auto Scaling Group với Target Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  lb_target_group_arn    = aws_lb_target_group.web_tg.arn
}

# Output DNS của Load Balancer
output "load_balancer_dns" {
  description = "DNS name of the Load Balancer"
  value       = aws_lb.web_lb.dns_name
}