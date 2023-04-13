# VPC
resource "aws_vpc" "demo" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Web Demo VPC"
  }
}

# Subnets
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.aws_availability_zone1

  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.aws_availability_zone2

  tags = {
    Name = "Public Subnet 2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.aws_availability_zone1

  tags = {
    Name = "Private Subnet 1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.aws_availability_zone2

  tags = {
    Name = "Private Subnet 2"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id
}

# NAT Gateways
resource "aws_eip" "ngw1" {
  vpc                       = true
  associate_with_private_ip = "10.0.1.100"
  depends_on                = [aws_internet_gateway.demo]
}

resource "aws_nat_gateway" "one" {
  allocation_id     = aws_eip.ngw1.id
  subnet_id         = aws_subnet.public_1.id
  private_ip        = "10.0.1.100"
  connectivity_type = "public"
  tags = {
    Name = "NAT GW 1"
  }

  depends_on = [aws_internet_gateway.demo]
}

resource "aws_eip" "ngw2" {
  vpc                       = true
  associate_with_private_ip = "10.0.2.100"
  depends_on                = [aws_internet_gateway.demo]
}

resource "aws_nat_gateway" "two" {
  allocation_id     = aws_eip.ngw2.id
  subnet_id         = aws_subnet.public_2.id
  private_ip        = "10.0.2.100"
  connectivity_type = "public"
  tags = {
    Name = "NAT GW 2"
  }

  depends_on = [aws_internet_gateway.demo]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.demo.id
  }

  tags = {
    Name = "Public RT"
  }
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.one.id
  }

  route {
    ipv6_cidr_block = "64:ff9b::/96"           # NAT GWs can only handle NAT64 prefixes
    gateway_id      = aws_nat_gateway.one.id
  }

  tags = {
    Name = "Private RT 1"
  }
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.two.id
  }

  route {
    ipv6_cidr_block = "64:ff9b::/96"           # NAT GWs can only handle NAT64 prefixes
    gateway_id      = aws_nat_gateway.two.id
  }

  tags = {
    Name = "Private RT 2"
  }
}

# Subnet / Route Table associations
resource "aws_route_table_association" "rtapub1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "rtapub2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "rtapvt1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "rtapvt2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}

# Security Group (for all ec2 instances)
resource "aws_security_group" "allow_web_ssh" {
  name        = "allow_web_ssh"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.demo.id

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

# Find an ami (latest stable ubuntu)
data "aws_ami" "ubuntu_linux" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

}

# EC2 (jump sever)
resource "aws_eip" "jump" {
  vpc                       = true
  network_interface         = aws_network_interface.jump.id
  associate_with_private_ip = "10.0.1.10"
  depends_on                = [aws_internet_gateway.demo]
}

resource "aws_network_interface" "jump" {
  subnet_id       = aws_subnet.public_1.id
  private_ips     = ["10.0.1.10"]
  security_groups = [aws_security_group.allow_web_ssh.id]
}


resource "aws_instance" "jump" {
  # if var.aws_ec2_ami is not set (default) use value from data source above
  ami               = (var.aws_ec2_ami == "" ? data.aws_ami.ubuntu_linux.id : var.aws_ec2_ami)
  instance_type     = var.aws_ec2_type_jump
  availability_zone = var.aws_availability_zone1
  key_name          = var.aws_ec2_keypair

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.jump.id
  }

  user_data = <<-EOF
                 #!/bin/bash
                 sudo apt update -y
                 EOF

  tags = {
    Name = "Jump Server 1"
  }
}


# ALB
resource "aws_lb" "demo" {
  name               = "aws-ec2-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_ssh.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

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

resource "aws_lb_listener" "demo" {
  load_balancer_arn = aws_lb.demo.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo.arn
  }
}

resource "aws_lb_target_group" "demo" {
  name     = "aws-ec2-demo-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo.id
}

resource "aws_lb_target_group_attachment" "one" {
  target_group_arn = aws_lb_target_group.demo.arn
  target_id        = aws_instance.web_server_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "two" {
  target_group_arn = aws_lb_target_group.demo.arn
  target_id        = aws_instance.web_server_2.id
  port             = 80
}


# EC2 (web servers)
resource "aws_network_interface" "web_server_1" {
  subnet_id       = aws_subnet.private_1.id
  private_ips     = ["10.0.3.50"]
  security_groups = [aws_security_group.allow_web_ssh.id]
}

resource "aws_network_interface" "web_server_2" {
  subnet_id       = aws_subnet.private_2.id
  private_ips     = ["10.0.4.50"]
  security_groups = [aws_security_group.allow_web_ssh.id]
}

resource "aws_instance" "web_server_1" {
  # if var.aws_ec2_ami is not set (default) use value from data source above
  ami               = (var.aws_ec2_ami == "" ? data.aws_ami.ubuntu_linux.id : var.aws_ec2_ami)
  instance_type     = var.aws_ec2_type_web
  availability_zone = var.aws_availability_zone1
  key_name          = var.aws_ec2_keypair

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web_server_1.id
  }

  user_data = file("web_install.sh")

  tags = {
    Name = "Web Server 1"
  }
}

resource "aws_instance" "web_server_2" {
  # if var.aws_ec2_ami is not set (default) use value from data source above
  ami               = (var.aws_ec2_ami == "" ? data.aws_ami.ubuntu_linux.id : var.aws_ec2_ami)
  instance_type     = var.aws_ec2_type_web
  availability_zone = var.aws_availability_zone2
  key_name          = var.aws_ec2_keypair

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web_server_2.id
  }

  user_data = file("web_install.sh")

  tags = {
    Name = "Web Server 2"
  }
}



# Outputs
output "aws_region" {
  value = var.aws_region
}

output "ami" {
  value = data.aws_ami.ubuntu_linux.id
}

output "jump_server_public_ip" {
  value = aws_eip.jump.public_ip
}

output "alb_dns_name" {
  value = aws_lb.demo.dns_name
}

