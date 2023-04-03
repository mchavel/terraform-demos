# VPC
resource "aws_vpc" "demo-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "EKS Demo VPC"
  }
}

# Subnets
resource "aws_subnet" "pub-subnet-1" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.aws_availability_zone1

  tags = {
    Name = "Public Subnet 1"
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/eks-cluster" = "owned"
  }
}

resource "aws_subnet" "pub-subnet-2" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.aws_availability_zone2

  tags = {
    Name = "Public Subnet 2"
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/eks-cluster" = "owned"
  }
}

resource "aws_subnet" "pvt-subnet-1" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.aws_availability_zone1

  tags = {
    Name = "Private Subnet 1"
    "kubernetes.io/role/elb-internal"   = "1"
    "kubernetes.io/cluster/eks-cluster" = "owned"
  }
}

resource "aws_subnet" "pvt-subnet-2" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.aws_availability_zone2

  tags = {
    Name = "Private Subnet 2" 
    "kubernetes.io/role/elb-internal"   = "1"
    "kubernetes.io/cluster/eks-cluster" = "owned"
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
resource "aws_security_group" "allow_icmp_ssh" {
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
    Name = "allow_icmp_ssh"
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
  security_groups = [aws_security_group.allow_icmp_ssh.id]
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

# EKS

resource "aws_iam_role" "iam-eks" {
  name = "iam-eks-cluster"

  assume_role_policy = <<POLICYEOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICYEOF
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.iam-eks.name
}

resource "aws_eks_cluster" "eks-cluster" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.iam-eks.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.pvt-subnet-1.id,
      aws_subnet.pvt-subnet-2.id,
      aws_subnet.pub-subnet-1.id,
      aws_subnet.pub-subnet-2.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks-AmazonEKSClusterPolicy]
}

# Nodes

resource "aws_iam_role" "iam-nodes" {
  name = "iam-eks-node-group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.iam-nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.iam-nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.iam-nodes.name
}

resource "aws_eks_node_group" "private-nodes" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "private-nodes"
  node_role_arn   = aws_iam_role.iam-nodes.arn

  subnet_ids = [
    aws_subnet.pvt-subnet-1.id,
    aws_subnet.pvt-subnet-2.id
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = [var.aws_ec2_type_node]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes-AmazonEC2ContainerRegistryReadOnly,
  ]
}



# Outputs
output "ami" {
  value = data.aws_ami.ubuntu_linux.id
}

output "jump_server_public_ip" {
  value = aws_eip.jump.public_ip
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks-cluster.name
}

