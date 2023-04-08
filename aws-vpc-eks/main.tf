# VPC
resource "aws_vpc" "demo" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "EKS Demo VPC"
  }
}

# Subnets
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.aws_availability_zone1

  tags = {
    Name = "Public Subnet 1"
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/${var.aws_eks_clustername}" = "owned"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.aws_availability_zone2

  tags = {
    Name = "Public Subnet 2"
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/${var.aws_eks_clustername}" = "owned"
    
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.aws_availability_zone1

  tags = {
    Name = "Private Subnet 1"
    "kubernetes.io/role/elb-internal"   = "1"
    "kubernetes.io/cluster/${var.aws_eks_clustername}" = "owned"
    
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.aws_availability_zone2

  tags = {
    Name = "Private Subnet 2" 
    "kubernetes.io/role/elb-internal"   = "1"
    "kubernetes.io/cluster/${var.aws_eks_clustername}" = "owned"
    
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
resource "aws_security_group" "allow_icmp_ssh" {
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
    Name = "allow_icmp_ssh"
  }
}

# Find an ami for jump server (latest stable ubuntu)
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
  depends_on                = [aws_internet_gateway.demoG]
}
 
resource "aws_network_interface" "jump" {
  subnet_id       = aws_subnet.public_1.id
  private_ips     = ["10.0.1.10"]
  security_groups = [aws_security_group.allow_icmp_ssh.id]
}

resource "aws_instance" "jump" {
  # if var.aws_ec2_ami is not set (default) use value from data source above
  ami               = (var.aws_ec2_ami_jump == "" ? data.aws_ami.ubuntu_linux.id : var.aws_ec2_ami_jump)
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

# EKS Cluster
resource "aws_iam_role" "eks" {
  name = "${var.aws_eks_clustername}Role"

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

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_eks_cluster" "demo" {
  name     = var.aws_eks_clustername
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id,
      aws_subnet.public_1.id,
      aws_subnet.public_2.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_AmazonEKSClusterPolicy]
}

# Node Group

resource "aws_iam_role" "nodes" {
  name = "${var.aws_eks_clustername}NodesRole"

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

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_eks_node_group" "private-nodes" {
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "${var.aws_eks_clustername}NodeGroup"
  node_role_arn   = aws_iam_role.nodes.arn

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = [var.aws_ec2_type_node]

  scaling_config {
    desired_size = var.aws_nodes_desired
    max_size     = var.aws_nodes_max
    min_size     = var.aws_nodes_min
  }

  update_config {
    max_unavailable = 1
  }

  remote_access {
    ec2_ssh_key = var.aws_ec2_keypair
  }

  labels = {
    role = "general"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
  ]
}


# IAM OIDC Provider (required for EKS add-ons and AWS LB controller)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.demo.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.demo.identity[0].oidc[0].issuer
}

### EBS CSI Driver add-on (necessary for dynamic creation of EBS persistent volumes) 

# EBS CSI Driver Role
data "aws_iam_policy_document" "csi" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_ebs_csi_driver" {
  assume_role_policy = data.aws_iam_policy_document.csi.json
  name               = "${var.aws_eks_clustername}EBSCSIDriverRole"
}

resource "aws_iam_role_policy_attachment" "amazon_ebs_csi_driver" {
  role       = aws_iam_role.eks_ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Install EKS EBS CSI driver add-on
resource "aws_eks_addon" "csi_driver" {
  cluster_name             = aws_eks_cluster.demo.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.17.0-eksbuild.1"                 # update addon version as needed
  service_account_role_arn = aws_iam_role.eks_ebs_csi_driver.arn
  resolve_conflicts    = "OVERWRITE"
}


### CoreDNS add-on

# Install CoreDNS add-on
resource "aws_eks_addon" "coredns" {
  cluster_name             = aws_eks_cluster.demo.name
  addon_name               = "coredns"
  addon_version            = "v1.9.3-eksbuild.2"              # update addon version as needed
  resolve_conflicts    = "OVERWRITE"  
}


### kube-proxy add-on

# Install kube-proxy add-on
resource "aws_eks_addon" "kube-proxy" {
  cluster_name             = aws_eks_cluster.demo.name
  addon_name               = "kube-proxy"
  addon_version            = "v1.25.6-eksbuild.2"             # update addon version as needed
  resolve_conflicts    = "OVERWRITE"
}


### VPC CNI add-on

# VPC CNI IAM Role
data "aws_iam_policy_document" "cni" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cni" {
  assume_role_policy = data.aws_iam_policy_document.cni.json
  name               = "${var.aws_eks_clustername}VPCCNIRole"
}

# Associate VPC CNI IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.cni.name
}

# Install VPC CNI add-on
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.demo.name
  addon_name               = "vpc-cni"
  addon_version            = "v1.12.6-eksbuild.1"             # update addon version as needed
  service_account_role_arn = aws_iam_role.cni.arn
  resolve_conflicts    = "OVERWRITE"
}


### IAM Policy and Role for AWS Load Balancer 

# Datasource: AWS Load Balancer Controller IAM Policy get from aws-load-balancer-controller/ GIT Repo (latest)
data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

# AWS Load Balancer Controller IAM Policy 
resource "aws_iam_policy" "lbc" {
  name        = "${var.aws_eks_clustername}LoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS Load Balancer Controller IAM Policy"
  policy      = data.http.lbc_iam_policy.response_body
}

# AWS Load Balancer IAM Role
data "aws_iam_policy_document" "lbc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "lbc" {
  assume_role_policy = data.aws_iam_policy_document.lbc.json
  name               = "${var.aws_eks_clustername}LBCRole"
}

# Associate Load Balanacer Controller IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "lbc" {
  policy_arn = aws_iam_policy.lbc.arn
  role       = aws_iam_role.lbc.name
}

# Note: AWS Load Balancer Controller is installed by separately via Helm chart



# Outputs
output "aws_region" {
  value = var.aws_region
}

output "jump_server_ami" {
  value = data.aws_ami.ubuntu_linux.id
}

output "jump_server_public_ip" {
  value = aws_eip.jump.public_ip
}

output "eks_cluster_name" {
  value = aws_eks_cluster.demo.name
}

output "lbc_iam_role_arn" {
  value       = aws_iam_role.lbc.arn
}
