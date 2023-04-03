# VPC
resource "aws_vpc" "demo-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Web Demo VPC"
  }
}

# Subnets
resource "aws_subnet" "pub-subnet-1" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.aws_availability_zone1

  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "pub-subnet-2" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.aws_availability_zone2

  tags = {
    Name = "Public Subnet 2"
  }
}

resource "aws_subnet" "pvt-subnet-1" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.aws_availability_zone1

  tags = {
    Name = "Private Subnet 1"
  }
}

resource "aws_subnet" "pvt-subnet-2" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.aws_availability_zone2

  tags = {
    Name = "Private Subnet 2"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.demo-vpc.id
}

# NAT Gateways
resource "aws_eip" "ngw1" {
  vpc                       = true
  associate_with_private_ip = "10.0.1.100"
  depends_on                = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "gw1" {
  allocation_id     = aws_eip.ngw1.id
  subnet_id         = aws_subnet.pub-subnet-1.id
  private_ip        = "10.0.1.100"
  connectivity_type = "public"
  tags = {
    Name = "NAT GW 1"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip" "ngw2" {
  vpc                       = true
  associate_with_private_ip = "10.0.2.100"
  depends_on                = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "gw2" {
  allocation_id     = aws_eip.ngw2.id
  subnet_id         = aws_subnet.pub-subnet-2.id
  private_ip        = "10.0.2.100"
  connectivity_type = "public"
  tags = {
    Name = "NAT GW 2"
  }

  depends_on = [aws_internet_gateway.gw]
}

# Route Tables
resource "aws_route_table" "pub-route-table" {
  vpc_id = aws_vpc.demo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public RT"
  }
}

resource "aws_route_table" "pvt-route-table1" {
  vpc_id = aws_vpc.demo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.gw1.id
  }

  route {
    ipv6_cidr_block = "64:ff9b::/96"           # NAT GWs can only handle NAT64 prefixes
    gateway_id      = aws_nat_gateway.gw1.id
  }

  tags = {
    Name = "Private RT 1"
  }
}

resource "aws_route_table" "pvt-route-table2" {
  vpc_id = aws_vpc.demo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.gw2.id
  }

  route {
    ipv6_cidr_block = "64:ff9b::/96"           # NAT GWs can only handle NAT64 prefixes
    gateway_id      = aws_nat_gateway.gw2.id
  }

  tags = {
    Name = "Private RT 2"
  }
}

# Subnet / Route Table associations
resource "aws_route_table_association" "rtapub1" {
  subnet_id      = aws_subnet.pub-subnet-1.id
  route_table_id = aws_route_table.pub-route-table.id
}

resource "aws_route_table_association" "rtapub2" {
  subnet_id      = aws_subnet.pub-subnet-2.id
  route_table_id = aws_route_table.pub-route-table.id
}

resource "aws_route_table_association" "rtapvt1" {
  subnet_id      = aws_subnet.pvt-subnet-1.id
  route_table_id = aws_route_table.pvt-route-table1.id
}

resource "aws_route_table_association" "rtapvt2" {
  subnet_id      = aws_subnet.pvt-subnet-2.id
  route_table_id = aws_route_table.pvt-route-table2.id
}

# Security Group (for all ec2 instances)
resource "aws_security_group" "allow_web_ssh" {
  name        = "allow_web_ssh"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.demo-vpc.id

  ingress {
    description      = "ICMP"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = [var.aws_sg_ingress_ipv4_block]
    ipv6_cidr_blocks = [var.aws_sg_ingress_ipv6_block]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.aws_sg_ingress_ipv4_block]
    ipv6_cidr_blocks = [var.aws_sg_ingress_ipv6_block]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [var.aws_sg_ingress_ipv4_block]
    ipv6_cidr_blocks = [var.aws_sg_ingress_ipv6_block]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.aws_sg_ingress_ipv4_block]
    ipv6_cidr_blocks = [var.aws_sg_ingress_ipv6_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_ssh"
  }
}

# ALB
resource "aws_lb" "alb" {
  name               = "aws-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_ssh.id]
  subnets            = [aws_subnet.pub-subnet-1.id, aws_subnet.pub-subnet-2.id]

  enable_deletion_protection = false

  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.id
  #   prefix  = "test-lb"
  #   enabled = true
  # }

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "alb-listner" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-tg.arn
  }
}

resource "aws_lb_target_group" "alb-tg" {
  name     = "aws-ec2-demo-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo-vpc.id
}

# Find an ami (latest stable ubuntu)
data "aws_ami" "ubuntu_linux" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-*"]
  }
}

# Launch Template
resource "aws_launch_template" "web_template" {
  name = "web-template"
  description = "Launch Template for web instances"
  # if var.aws_ec2_ami is not set (default) use value from data source above
  image_id = (var.aws_ec2_ami == "" ? data.aws_ami.ubuntu_linux.id : var.aws_ec2_ami) 
  instance_type = var.aws_ec2_type_web

  vpc_security_group_ids = [aws_security_group.allow_web_ssh.id]
  key_name = var.aws_ec2_keypair  
  user_data = filebase64("web_install.sh")
  #ebs_optimized = true  # Not availble with t2.micro
  #default_version = 1
  #update_default_version = true

  #monitoring {
  #  enabled = true
  #}

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-asg"
    }
  }
}

# Autoscaling Group
resource "aws_autoscaling_group" "web_asg" {
  name_prefix = "webasg-"
  desired_capacity   = 2
  max_size           = 6
  min_size           = 2
  vpc_zone_identifier  = [ aws_subnet.pvt-subnet-1.id, aws_subnet.pvt-subnet-2.id ]
  target_group_arns = [aws_lb_target_group.alb-tg.arn]
  health_check_type = "ELB"
  health_check_grace_period = 300 # default is 300 seconds  
  # Launch Template
  launch_template {
    id      = aws_launch_template.web_template.id
    version = aws_launch_template.web_template.latest_version
  }
  # Instance Refresh
  instance_refresh {
    strategy = "Rolling"
    preferences {
      #instance_warmup = 300 # Default behavior is the Auto Scaling Group's health check grace period.
      #min_healthy_percentage = 50  # Default is 90
    }
    #triggers = [ /*"launch_template",*/ "desired_capacity" ] 
  }  
}      


# EC2 (jump sever)
resource "aws_eip" "jump" {
  vpc                       = true
  network_interface         = aws_network_interface.jump-server1-nic.id
  associate_with_private_ip = "10.0.1.10"
  depends_on                = [aws_internet_gateway.gw]
}

resource "aws_network_interface" "jump-server1-nic" {
  subnet_id       = aws_subnet.pub-subnet-1.id
  private_ips     = ["10.0.1.10"]
  security_groups = [aws_security_group.allow_web_ssh.id]
}

resource "aws_instance" "jump-instance" {
  # if var.aws_ec2_ami is not set (default) use value from data source above
  ami               = (var.aws_ec2_ami == "" ? data.aws_ami.ubuntu_linux.id : var.aws_ec2_ami)
  instance_type     = var.aws_ec2_type_jump
  availability_zone = var.aws_availability_zone1
  key_name          = var.aws_ec2_keypair

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.jump-server1-nic.id
  }

  user_data = <<-EOF
                 #!/bin/bash
                 sudo apt update -y
                 EOF

  tags = {
    Name = "Jump Server 1"
  }
}


# Outputs
output "ami" {
  value = data.aws_ami.ubuntu_linux.id
}

output "jump_server_public_ip" {
  value = aws_eip.jump.public_ip
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

